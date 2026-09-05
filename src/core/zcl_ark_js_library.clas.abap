CLASS zcl_ark_js_library DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    "! 注册一个 JS 库（会话级，按 iv_name 唯一）。来源四选一：
    "! iv_mime（SMW0 MIME 对象，上传本地 js 文件的入口）、iv_url（CDN/内网
    "! 静态服务）、iv_xdata（原始 UTF-8 字节）、iv_inline（内联脚本文本）。
    "! 同名重复注册以最新一次为准。
    "!
    "! 用法（接入 three.js 等任意库）：
    "!   1) SMW0 上传 three.min.js 为 MIME 对象（如 ZARK_THREE_MIN_JS），
    "!      注意用 UMD/全局构建而非 ES module 版本
    "!   2) zcl_ark_js_library=>register( iv_name = 'three'
    "!                                    iv_mime = 'ZARK_THREE_MIN_JS' ).
    "!   3) 页面构建时 zcl_ark_js_library=>include( 'three' ) —— 同页幂等
    CLASS-METHODS register
      IMPORTING
        !iv_name   TYPE string
        !iv_mime   TYPE wwwdatatab-objid OPTIONAL
        !iv_url    TYPE string OPTIONAL
        !iv_xdata  TYPE xstring OPTIONAL
        !iv_inline TYPE string OPTIONAL
      RAISING
        zcx_ark_exception .

    "! 输出 <script> 引入标签（MIME/xdata 来源经 cache_asset 换成本地
    "! 缓存 URL；url 来源原样引用；inline 来源内联脚本体）。
    "! 同页同名只注入一次（页面作用域去重，zcl_ark_gui=>render 时重置）。
    "! 解析失败返回空串（调用方自行降级），get_url 用于需要报错的场景
    CLASS-METHODS include
      IMPORTING
        !iv_name       TYPE string
      RETURNING
        VALUE(rv_html) TYPE string .

    "! 解析为可引用的 URL（MIME/xdata 来源先 cache_asset 上传换 URL）。
    "! 未注册/解析失败抛异常
    CLASS-METHODS get_url
      IMPORTING
        !iv_name       TYPE string
      RETURNING
        VALUE(rv_url)  TYPE string
      RAISING
        zcx_ark_exception .

    CLASS-METHODS is_registered
      IMPORTING
        !iv_name          TYPE string
      RETURNING
        VALUE(rv_yes)     TYPE abap_bool .

    "! 清空页面作用域去重集（由 zcl_ark_gui=>render 在每次整页渲染前调用；
    "! 桥脚本的去重也由此一并重置）
    CLASS-METHODS reset_page_scope .

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_library,
        name        TYPE string,
        mime        TYPE wwwdatatab-objid,
        url         TYPE string,
        xdata       TYPE xstring,
        inline      TYPE string,
        mime_failed TYPE abap_bool,
      END OF ty_library,
      tt_library TYPE HASHED TABLE OF ty_library WITH UNIQUE KEY name .
    CLASS-DATA gt_libraries TYPE tt_library .
    CLASS-DATA gt_included TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line .

    CLASS-METHODS resolve_url
      IMPORTING
        !is_lib        TYPE ty_library
      RETURNING
        VALUE(rv_url)  TYPE string
      RAISING
        zcx_ark_exception .
ENDCLASS.



CLASS zcl_ark_js_library IMPLEMENTATION.


  METHOD register.
    IF iv_name IS INITIAL.
      zcx_ark_exception=>raise( 'JS library name is required' ).
    ENDIF.
    IF iv_mime IS INITIAL AND iv_url IS INITIAL
       AND iv_xdata IS INITIAL AND iv_inline IS INITIAL.
      zcx_ark_exception=>raise( |JS library { iv_name }: no source given| ).
    ENDIF.

    "! 同名重注册覆盖（内容更新场景）
    DATA ls_lib TYPE ty_library.
    ls_lib-name   = iv_name.
    ls_lib-mime   = iv_mime.
    ls_lib-url    = iv_url.
    ls_lib-xdata  = iv_xdata.
    ls_lib-inline = iv_inline.

    INSERT ls_lib INTO TABLE gt_libraries.
    IF sy-subrc <> 0.
      MODIFY TABLE gt_libraries FROM ls_lib.
    ENDIF.
  ENDMETHOD.


  METHOD include.
    " 页面作用域幂等：同页同名只注入一次
    READ TABLE gt_included TRANSPORTING NO FIELDS WITH KEY table_line = iv_name.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    READ TABLE gt_libraries INTO DATA(ls_lib) WITH KEY name = iv_name.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " 内联脚本无需 URL 解析，直接输出脚本体
    IF ls_lib-inline IS NOT INITIAL.
      INSERT iv_name INTO TABLE gt_included.
      rv_html = |<script type="text/javascript">{ ls_lib-inline }</script>|.
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_url) = get_url( iv_name ).
      CATCH zcx_ark_exception.
        " 解析失败不注入（调用方/初始化脚本的守卫负责降级提示）
        RETURN.
    ENDTRY.

    IF lv_url IS INITIAL.
      RETURN.
    ENDIF.

    INSERT iv_name INTO TABLE gt_included.
    rv_html = |<script src="{ lv_url }"></script>|.
  ENDMETHOD.


  METHOD get_url.
    READ TABLE gt_libraries INTO DATA(ls_lib) WITH KEY name = iv_name.
    IF sy-subrc <> 0.
      zcx_ark_exception=>raise( |JS library not registered: { iv_name }| ).
    ENDIF.

    " 不在注册器层缓存解析出的 URL：load_data 的 URL 绑定 GUI 控件实例，
    " 控件销毁重建后失效。重复 resolve 是廉价的（cache_asset 内部按
    " GUI 实例去重，之后只是哈希查找）
    rv_url = resolve_url( ls_lib ).
  ENDMETHOD.


  METHOD is_registered.
    READ TABLE gt_libraries TRANSPORTING NO FIELDS WITH KEY name = iv_name.
    rv_yes = boolc( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD reset_page_scope.
    CLEAR gt_included.
    zcl_ark_js_bridge=>reset_page_scope( ).
  ENDMETHOD.


  METHOD resolve_url.
    " 1) 显式 URL：原样引用（CDN / 内网静态服务）
    IF is_lib-url IS NOT INITIAL.
      rv_url = is_lib-url.
      RETURN.
    ENDIF.

    " 2) 调用方直接给的字节
    DATA(lv_xdata) = is_lib-xdata.

    " 3) MIME 对象：会话级只读一次（1MB+ 的 WWWDATA_IMPORT 很贵），
    "    读失败置标记，避免每次渲染重复昂贵读取
    IF lv_xdata IS INITIAL AND is_lib-mime IS NOT INITIAL.
      IF is_lib-mime_failed = abap_false.
        TRY.
            lv_xdata = zcl_ark_convert=>mime_to_xstring( is_lib-mime ).
          CATCH zcx_ark_exception.
            DATA(ls_failed) = is_lib.
            ls_failed-mime_failed = abap_true.
            MODIFY TABLE gt_libraries FROM ls_failed.
            zcx_ark_exception=>raise( |JS library MIME not available: { is_lib-mime }| ).
        ENDTRY.
      ELSE.
        zcx_ark_exception=>raise( |JS library MIME not available: { is_lib-mime }| ).
      ENDIF.
    ENDIF.

    IF lv_xdata IS INITIAL.
      zcx_ark_exception=>raise( |JS library { is_lib-name }: no content| ).
    ENDIF.

    " 上传到 HTML 控件换本地缓存 URL；GUI 实例销毁后 URL 失效，
    " 下次渲染 cache_asset 会重新分配
    rv_url = zcl_ark_gui=>get_instance( )->zif_ark_gui_services~cache_asset(
      iv_url     = |ark_js_{ is_lib-name }.js|
      iv_xdata   = lv_xdata
      iv_type    = 'text'
      iv_subtype = 'javascript' ).
  ENDMETHOD.


ENDCLASS.
