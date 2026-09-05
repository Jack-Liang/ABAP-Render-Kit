*=======================================================================
* 本地类 lcl_json_tables_page —— JSON 字符串 + 内表可视化页（ARK 框架）
*
* 展示部分全部走框架内建件（v2 重构）：
*   - 内表：zcl_ark_html_table=>from_any_table( ) —— RTTI 出列、DDIC 中文
*     列头、数字右对齐、日期用户格式、深层内表行数、HTML 转义，一行调用
*   - JSON：zcl_ark_json_tree —— sXML 折叠树 + 转义 + 折叠脚本内建，
*     非法 JSON 回退原文
* 本地只保留：宿主屏/悬浮窗生命周期、导出 Excel(SpreadsheetML)、下载
*
* 用法：把整个类粘贴进你的报表程序，然后：
*
*   场景 A —— 调用时屏幕已在前台（模块池 PAI/PBO、选择屏未离场等）：
*     lcl_json_tables_page=>display( ... ).   " 直接调用，viewer 挂当前屏幕
*     注意：报表 START-OF-SELECTION 等处理块里前台【无屏幕】，直接调用
*     什么都不显示 —— 改用 iv_floating = abap_true + CALL SELECTION-SCREEN
*     1001 保持程序存活（见场景 B/C），或走场景 C 悬浮窗。
*
*   场景 C —— 从 ALV 等已有屏幕双击下钻（screen0 会被压在 ALV 下层）：
*     lcl_json_tables_page=>display( ... iv_floating = abap_true ).
*     " 悬浮窗容器永远浮在上层，带标题栏；点 X 关闭；
*     " 重复双击自动释放旧实例再开新窗，ALV 本身不受影响
*
*   场景 B —— 纯报表 START-OF-SELECTION 之后调用（前台无 dynpro，控件需宿主）：
*     TRY.
*         lcl_json_tables_page=>display(
*             iv_json1  = lv_json1          " TYPE string，可选
*             iv_json2  = lv_json2          " TYPE string，可选
*             it_table1 = lt_tab1           " TYPE ANY TABLE，字段动态识别
*             it_table2 = lt_tab2
*             it_table3 = lt_tab3
*             it_table4 = lt_tab4 ).
*         CALL SELECTION-SCREEN 1001.       " dummy 宿主屏幕（HTML viewer 需要）
*       CATCH zcx_ark_exception INTO DATA(lx_error).
*         MESSAGE lx_error TYPE 'E'.
*     ENDTRY.
*     " 1001 需在程序里声明：SELECTION-SCREEN BEGIN OF SCREEN 1001. END OF SCREEN 1001.
*     " 退出时释放控件：
*     "   AT SELECTION-SCREEN ON EXIT-COMMAND.
*     "     IF sy-dynnr = 1001.
*     "       zcl_ark_gui=>get_instance( )->free( ).
*     "       LEAVE PROGRAM.
*     "     ENDIF.
*
* 页面内容：
*   - 2 个 JSON 字符串：折叠树（框架组件；默认全折叠）
*   - 工具条：全部展开 / 全部折叠（sapevent 同页重渲染，JSON 树 + 内表一起生效）
*   - 4 个内表（ZTHR_AUTH_H / ZTHR_AUTH_I / ZTHR_AUTH_S / ZTHR_AUTH）：
*       框架 RTTI 动态出列，默认折叠只显示条数
*   - 每张卡片单独导出：JSON 下载为 .json 文件；内表导出 .xls
*     （SpreadsheetML，Excel 直开，零依赖；均走 sapevent + 前端服务写文件）
*
* 依赖：zcl_ark_gui / zcl_ark_gui_page / zcl_ark_html_table(=>from_any_table)
*       / zcl_ark_json_tree / zcl_ark_convert（均在 ARK src/ 内）
*=======================================================================

CLASS lcl_json_tables_page DEFINITION INHERITING FROM zcl_ark_gui_page FINAL.

  PUBLIC SECTION.
    METHODS constructor.

    "! 显示入口：两个 JSON 字符串（可选）+ 四个任意内表
    CLASS-METHODS display
      IMPORTING !iv_json1   TYPE string OPTIONAL
                !iv_json2   TYPE string OPTIONAL
                !it_table1  TYPE ANY TABLE
                !it_table2  TYPE ANY TABLE
                !it_table3  TYPE ANY TABLE
                !it_table4  TYPE ANY TABLE
                !iv_floating TYPE abap_bool DEFAULT abap_false
      RAISING   zcx_ark_exception.

    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
    METHODS build_html REDEFINITION .

  PRIVATE SECTION.
    " GUI 单例静态引用：生命周期判断用 IS BOUND，绝不用 get_instance ——
    " 无实例时它会凭空创建 screen0 viewer，压住 ALV 并破坏返回屏幕序列
    CLASS-DATA go_gui TYPE REF TO zcl_ark_gui .
    " 悬浮窗容器（静态：display 里须先于页面创建；close 事件仅隐藏不销毁）
    CLASS-DATA go_dialog_box TYPE REF TO cl_gui_dialogbox_container .

    DATA mv_json1     TYPE string .
    DATA mv_json2     TYPE string .
    DATA mr_table1    TYPE REF TO data .
    DATA mr_table2    TYPE REF TO data .
    DATA mr_table3    TYPE REF TO data .
    DATA mr_table4    TYPE REF TO data .
    " JSON 树与内表区块的默认展开状态（默认全折叠；全部展开/全部折叠按钮一起切换）
    DATA mv_json_open TYPE abap_bool VALUE abap_false .

    METHODS set_data
      IMPORTING !iv_json1  TYPE string OPTIONAL
                !iv_json2  TYPE string OPTIONAL
                !it_table1 TYPE ANY TABLE
                !it_table2 TYPE ANY TABLE
                !it_table3 TYPE ANY TABLE
                !it_table4 TYPE ANY TABLE .

    METHODS copy_table
      IMPORTING !it_table      TYPE ANY TABLE
      RETURNING VALUE(rr_copy) TYPE REF TO data .

    METHODS add_json_block
      IMPORTING !iv_title  TYPE string
                !iv_json   TYPE string
                !iv_dl_act TYPE string OPTIONAL
      RAISING   zcx_ark_exception .

    " ---- 下载导出（sapevent + cl_gui_frontend_services 写前端文件） ----
    METHODS download_string_as_file
      IMPORTING !iv_name   TYPE string
                !iv_ext    TYPE string
                !iv_filter TYPE string
                !iv_str    TYPE string .

    METHODS build_table_excel_xml
      IMPORTING !ir_table      TYPE REF TO data
      RETURNING VALUE(rv_xml) TYPE string .

    CLASS-METHODS build_dialog_box
      RETURNING VALUE(ri_container) TYPE REF TO cl_gui_container .

    CLASS-METHODS on_dialog_close
      FOR EVENT close OF cl_gui_dialogbox_container .

    " ---- 内表渲染（框架 from_any_table + 折叠包装） ----
    METHODS render_table
      IMPORTING !ir_table      TYPE REF TO data
      RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html
      RAISING   zcx_ark_exception .
ENDCLASS.


CLASS lcl_json_tables_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( '日志详情' ).
  ENDMETHOD.


  METHOD display.
    " 重复进入：释放上一实例（按静态引用判断，见 go_gui 声明处注释）
    IF go_gui IS NOT INITIAL.
      TRY.
          go_gui->free( ).
        CATCH cx_root ##NO_TEXT.
      ENDTRY.
      CLEAR go_gui.
    ENDIF.

    " 顺序关键：GUI 实例（含悬浮窗容器）必须先于页面创建 —— 页面构造器
    " 内部调 zcl_ark_gui=>get_instance( )，若那时单例为空，会凭空创建
    " screen0 空 viewer：白屏盖住 ALV/选择屏，F3 回不到初始屏幕
    DATA lo_container TYPE REF TO cl_gui_container.
    IF iv_floating = abap_true.
      " screen0 会压在 ALV 下层，dialogbox 永远浮在上层
      lo_container = build_dialog_box( ).
    ENDIF.

    go_gui = zcl_ark_gui=>create( io_container = lo_container ).

    DATA(lo_page) = NEW lcl_json_tables_page( ).
    lo_page->set_data( iv_json1  = iv_json1
                       iv_json2  = iv_json2
                       it_table1 = it_table1
                       it_table2 = it_table2
                       it_table3 = it_table3
                       it_table4 = it_table4 ).

    go_gui->set_page( lo_page ).
  ENDMETHOD.


  METHOD build_dialog_box.
    IF go_dialog_box IS NOT INITIAL.
      TRY.
          go_dialog_box->free( ).
        CATCH cx_root ##NO_TEXT.
      ENDTRY.
      CLEAR go_dialog_box.
    ENDIF.

    CREATE OBJECT go_dialog_box
      EXPORTING
        top     = 30
        left    = 30
        width   = 940
        height  = 620
        caption = '日志详情'.

    SET HANDLER on_dialog_close FOR go_dialog_box.
    ri_container = go_dialog_box.
  ENDMETHOD.


  METHOD on_dialog_close.
    " 点 X 或离开屏幕触发 close：仅隐藏悬浮窗，绝不在 close 事件里 free ——
    " 屏幕切换过程中销毁控件会破坏返回序列（F3 回不到选择屏）。
    " 真正的释放由下一次 display 开头统一完成；程序结束时框架自清理
    IF go_dialog_box IS NOT INITIAL.
      TRY.
          go_dialog_box->set_visible( abap_false ).
        CATCH cx_root ##NO_TEXT.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD set_data.
    mv_json1  = iv_json1.
    mv_json2  = iv_json2.
    mr_table1 = copy_table( it_table = it_table1 ).
    mr_table2 = copy_table( it_table = it_table2 ).
    mr_table3 = copy_table( it_table = it_table3 ).
    mr_table4 = copy_table( it_table = it_table4 ).
  ENDMETHOD.


  METHOD copy_table.
    " CREATE DATA ... LIKE 对 ANY TABLE 形参在运行时取实际类型，整表拷贝避免悬空引用
    FIELD-SYMBOLS <lt_copy> TYPE ANY TABLE.
    CREATE DATA rr_copy LIKE it_table.
    ASSIGN rr_copy->* TO <lt_copy>.
    <lt_copy> = it_table.
  ENDMETHOD.


  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'json_expand' OR 'json_collapse'.
        mv_json_open = xsdbool( ii_event->mv_action = 'json_expand' ).
        " state 置位且不带新 page：框架 render( ) 同页重渲染，折叠状态生效
        rs_result-state = 1.

      WHEN 'dl_json1' OR 'dl_json2'.
        " keep_view：不重渲染，保持用户已展开/折叠的树状态
        download_string_as_file(
            iv_name   = COND string( WHEN ii_event->mv_action = 'dl_json1'
                                     THEN '档案分组权限接口返回.json'
                                     ELSE '部门权限接口返回.json' )
            iv_ext    = 'json'
            iv_filter = `JSON 文件 (*.json)|*.json`
            iv_str    = COND string( WHEN ii_event->mv_action = 'dl_json1'
                                     THEN mv_json1 ELSE mv_json2 ) ).
        rs_result-state      = 1.
        rs_result-keep_view  = abap_true.

      WHEN 'dl_tbl1' OR 'dl_tbl2' OR 'dl_tbl3' OR 'dl_tbl4'.
        DATA: lv_idx    TYPE i,
              lv_suffix TYPE string,
              lr_table  TYPE REF TO data.
        lv_idx = ii_event->mv_action+6(1).      " 'dl_tblN' -> N
        CASE lv_idx.
          WHEN 1. lv_suffix = '_H'. lr_table = mr_table1.
          WHEN 2. lv_suffix = '_I'. lr_table = mr_table2.
          WHEN 3. lv_suffix = '_S'. lr_table = mr_table3.
          WHEN 4. lv_suffix = ''.   lr_table = mr_table4.
        ENDCASE.

        download_string_as_file(
            iv_name   = |ZTHR_AUTH{ lv_suffix }.xls|
            iv_ext    = 'xls'
            iv_filter = `Excel 文件 (*.xls)|*.xls`
            iv_str    = build_table_excel_xml( ir_table = lr_table ) ).
        rs_result-state      = 1.
        rs_result-keep_view  = abap_true.

      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.


  METHOD build_html.
    " 页面级样式只保留本页专属部分：头部栏/卡片/表格边框覆写。
    " JSON 树与折叠节点样式（ark-jt-*）由 zcl_ark_theme 统一供给了
    mo_html->add_css(
      `body { font-family:"72","72full",Arial,Helvetica,sans-serif; background:#f0f5fa; }` &&
      `a   { color:#0070f2; text-decoration:none; }` &&
      `.jt-header  { background:#354a5f; border-radius:6px; padding:10px 16px; margin-bottom:16px; }` &&
      `.jt-header-title { color:#fff; font-size:18px; font-weight:bold; margin-left:8px; }` &&
      `.jt-header-tools { display:inline-block; }` &&
      `a.jt-btn   { display:inline-block; color:#fff; padding:4px 12px; margin-right:8px;` &&
      `             border:1px solid rgba(255,255,255,0.5); border-radius:4px; font-size:13px;` &&
      `             vertical-align:middle; }` &&
      `a.jt-btn:hover { background:rgba(255,255,255,0.15); }` &&
      `.jt-card    { display:inline-block; vertical-align:top; width:46%; min-width:340px;` &&
      `               margin:0 12px 16px 0; border:1px solid #d9dee3; border-radius:8px; background:#fff;` &&
      `               box-shadow:0 1px 3px rgba(0,0,0,0.12); }` &&
      `.jt-title   { padding:8px 12px; font-weight:bold; color:#32363a; border-bottom:1px solid #eaecef;` &&
      `               background:#f8fafc; border-radius:8px 8px 0 0; }` &&
      `.jt-empty   { color:#6a6d70; font-style:italic; }` &&
      `.jt-title a { font-weight:normal; font-size:12px; margin-left:12px; color:#0070f2; }` &&
      `h2          { font-size:16px; color:#32363a; border-bottom:1px solid #d9dee3;` &&
      `               padding-bottom:6px; margin-top:28px; }` &&
      `h2 a        { font-size:13px; font-weight:normal; margin-left:12px; }` &&
      `table.ark-table { border-collapse:collapse; background:#fff; }` &&
      `.ark-table th { background:#f5f7fa; color:#4a4f54; font-size:12px; border:1px solid #d9dee3;` &&
      `                 padding:6px 8px; text-align:left; }` &&
      `.ark-table td { color:#32363a; border:1px solid #e2e6ea; padding:5px 8px; }` &&
      `.ark-table tr:hover td { background:#eef4fb; }` ).

    " 节点折叠/展开的切换脚本：内表折叠包装需要它；JSON 树组件会随片段
    " 输出同名同体的函数（互相覆盖、无害），此处保证"只传内表不传 JSON"
    " 时包装仍可折叠
    mo_html->add_js(
      `function arkJtTg(e){var n=e.parentNode;` &&
      `if(n.getAttribute('data-open')==='1'){n.setAttribute('data-open','0');}` &&
      `else{n.setAttribute('data-open','1');}}` ).

    " ---- Fiori 头部栏：标题 + 全部展开/全部折叠按钮（sapevent 同页重渲染） ----
    mo_html->add( |<div class="jt-header"><span class="jt-header-tools">| ).
    mo_html->add_a( iv_txt = '全部展开' iv_act = 'json_expand' iv_class = 'jt-btn' ).
    mo_html->add_a( iv_txt = '全部折叠' iv_act = 'json_collapse' iv_class = 'jt-btn' ).
    mo_html->add( |</span><span class="jt-header-title">日志详情</span></div>| ).

    " ---- 两个 JSON 字符串（未传入的整卡不渲染） ----
    add_json_block( iv_title = '档案分组权限接口返回' iv_json = mv_json1 iv_dl_act = 'dl_json1' ).
    add_json_block( iv_title = '部门权限接口返回'     iv_json = mv_json2 iv_dl_act = 'dl_json2' ).

    " ---- 四个内表 ----
    mo_html->add( |<h2>ZTHR_AUTH_H { mo_html->a( iv_txt = '导出 Excel' iv_act = 'dl_tbl1' ) }</h2>| ).
    mo_html->add( render_table( ir_table = mr_table1 ) ).

    mo_html->add( |<h2>ZTHR_AUTH_I { mo_html->a( iv_txt = '导出 Excel' iv_act = 'dl_tbl2' ) }</h2>| ).
    mo_html->add( render_table( ir_table = mr_table2 ) ).

    mo_html->add( |<h2>ZTHR_AUTH_S { mo_html->a( iv_txt = '导出 Excel' iv_act = 'dl_tbl3' ) }</h2>| ).
    mo_html->add( render_table( ir_table = mr_table3 ) ).

    mo_html->add( |<h2>ZTHR_AUTH { mo_html->a( iv_txt = '导出 Excel' iv_act = 'dl_tbl4' ) }</h2>| ).
    mo_html->add( render_table( ir_table = mr_table4 ) ).

    ri_html = mo_html.
  ENDMETHOD.


  METHOD add_json_block.
    " 未传 / 空 JSON：整个卡片不展示（无标题框、无占位）
    IF iv_json IS INITIAL.
      RETURN.
    ENDIF.

    " 标题栏右侧挂下载链接（sapevent，on_event 走前端服务写文件）
    DATA lv_title TYPE string.
    lv_title = zcl_ark_convert=>escape_html( iv_text = iv_title ).
    IF iv_dl_act IS NOT INITIAL.
      lv_title = lv_title && mo_html->a( iv_txt = '下载' iv_act = iv_dl_act ).
    ENDIF.

    mo_html->add( |<div class="jt-card"><div class="jt-title">{ lv_title }</div>| ).
    mo_html->add( zcl_ark_json_tree=>create( iv_json
                              )->set_open( iv_open = mv_json_open
                              )->zif_ark_gui_renderable~render( ) ).
    mo_html->add( |</div>| ).
  ENDMETHOD.


  METHOD render_table.
    FIELD-SYMBOLS <lt_tab> TYPE ANY TABLE.

    DATA(lo_wrap) = zcl_ark_html=>create( ).

    IF ir_table IS NOT BOUND.
      lo_wrap->add( |<p class="jt-empty">（未传入数据）</p>| ).
      ri_html = lo_wrap.
      RETURN.
    ENDIF.
    ASSIGN ir_table->* TO <lt_tab>.

    IF <lt_tab> IS INITIAL.
      lo_wrap->add( |<p class="jt-empty">（空表，0 行）</p>| ).
      ri_html = lo_wrap.
      RETURN.
    ENDIF.

    " 任意内表 -> 表格：RTTI 出列、DDIC 列头、数值右对齐、日期用户格式、
    " 深层内表行数、HTML 转义 —— 全部框架内建
    DATA(li_table) = zcl_ark_html_table=>from_any_table( <lt_tab>
                              )->zif_ark_gui_renderable~render( ).

    " 默认折叠：只显示条数行，点击展开表格（与 JSON 树同一 JS 机制）；
    " mv_json_open 同时受"全部展开/全部折叠"按钮驱动，对两者一起生效
    DATA(lv_openflag) = COND string( WHEN mv_json_open = abap_true THEN `1` ELSE `0` ).
    lo_wrap->add( |<div class="ark-jt-node" data-open="{ lv_openflag }">| ).
    lo_wrap->add( |<div class="ark-jt-sum" onclick="arkJtTg(this)">共 { lines( <lt_tab> ) } 条数据</div>| ).
    lo_wrap->add( |<div class="ark-jt-kids">| ).
    lo_wrap->add( li_table ).
    lo_wrap->add( |</div></div>| ).
    ri_html = lo_wrap.
  ENDMETHOD.


  METHOD download_string_as_file.
    " 保存对话框 + UTF-8 字节写前端文件（JSON 与 Excel XML 共用）
    DATA: lv_filename TYPE string,
          lv_path     TYPE string,
          lv_fullpath TYPE string,
          lv_uaction  TYPE i.

    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        default_extension = iv_ext
        default_file_name = iv_name
        file_filter       = iv_filter
      CHANGING
        filename          = lv_filename
        path              = lv_path
        fullpath          = lv_fullpath
        user_action       = lv_uaction
      EXCEPTIONS
        OTHERS            = 1 ).
    IF sy-subrc <> 0 OR lv_fullpath IS INITIAL.
      RETURN.                       " 用户取消或对话框失败
    ENDIF.

    DATA(lv_xstr) = cl_abap_codepage=>convert_to( iv_str ).
    DATA(lt_bin) = cl_bcs_convert=>xstring_to_solix( lv_xstr ).

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize = xstrlen( lv_xstr )
        filename     = lv_fullpath
        filetype     = 'BIN'
      CHANGING
        data_tab     = lt_bin
      EXCEPTIONS
        OTHERS       = 1 ).
    IF sy-subrc <> 0.
      MESSAGE '文件写入失败' TYPE 'I'.
    ENDIF.
  ENDMETHOD.


  METHOD build_table_excel_xml.
    " 任意内表 -> SpreadsheetML（Excel 2003 XML）：零依赖 Excel 导出，
    " 存为 .xls 双击直开。整数列输出数字类型，其余按字符串（避免小数点
    " 本地化差异导致 Excel 解析失败）；列头复用框架 DDIC 标签逻辑
    DATA lo_tabledesc TYPE REF TO cl_abap_tabledescr.
    DATA lo_struct    TYPE REF TO cl_abap_structdescr.
    DATA ls_comp      TYPE cl_abap_structdescr=>component.
    FIELD-SYMBOLS <lt_tab>   TYPE ANY TABLE.
    FIELD-SYMBOLS <ls_row>   TYPE any.
    FIELD-SYMBOLS <lv_field> TYPE any.
    FIELD-SYMBOLS <lt_nest>  TYPE ANY TABLE.

    rv_xml = `<?xml version="1.0" encoding="utf-8"?>` &&
             `<?mso-application progid="Excel.Sheet"?>` &&
             `<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"` &&
             ` xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">` &&
             `<Styles><Style ss:ID="hdr"><Font ss:Bold="1"/></Style></Styles>` &&
             `<Worksheet ss:Name="Sheet1"><Table>`.

    IF ir_table IS NOT BOUND.
      rv_xml = rv_xml && `</Table></Worksheet></Workbook>`.
      RETURN.
    ENDIF.
    ASSIGN ir_table->* TO <lt_tab>.

    TRY.
        lo_tabledesc ?= cl_abap_tabledescr=>describe_by_data( <lt_tab> ).
      CATCH cx_sy_move_cast_error.
        rv_xml = rv_xml && `</Table></Worksheet></Workbook>`.
        RETURN.
    ENDTRY.

    DATA(lo_line) = lo_tabledesc->get_table_line_type( ).
    CLEAR lo_struct.
    IF lo_line->kind = cl_abap_typedescr=>kind_struct.
      TRY.
          lo_struct ?= lo_line.
        CATCH cx_sy_move_cast_error.
          CLEAR lo_struct.
      ENDTRY.
    ENDIF.

    IF lo_struct IS INITIAL.
      rv_xml = rv_xml &&
               `<Row><Cell ss:StyleID="hdr">` &&
               `<Data ss:Type="String">TABLE_LINE</Data></Cell></Row>`.
      LOOP AT <lt_tab> ASSIGNING <ls_row>.
        rv_xml = rv_xml && `<Row><Cell><Data ss:Type="String">` &&
                 zcl_ark_convert=>escape_html( iv_text = |{ <ls_row> }| ) &&
                 `</Data></Cell></Row>`.
      ENDLOOP.
    ELSE.
      DATA(lt_comp) = lo_struct->get_components( ).

      rv_xml = rv_xml && `<Row>`.
      LOOP AT lt_comp INTO ls_comp.
        rv_xml = rv_xml && `<Cell ss:StyleID="hdr"><Data ss:Type="String">` &&
                 zcl_ark_html_table=>ddic_header( is_comp = ls_comp ) &&
                 `</Data></Cell>`.
      ENDLOOP.
      rv_xml = rv_xml && `</Row>`.

      LOOP AT <lt_tab> ASSIGNING <ls_row>.
        rv_xml = rv_xml && `<Row>`.
        LOOP AT lt_comp INTO ls_comp.
          ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_row> TO <lv_field>.
          IF sy-subrc <> 0.
            rv_xml = rv_xml && `<Cell><Data ss:Type="String"></Data></Cell>`.
            CONTINUE.
          ENDIF.

          DATA lv_cell TYPE string.
          DATA lv_type TYPE string.
          lv_type = `String`.
          CASE ls_comp-type->kind.
            WHEN cl_abap_datadescr=>kind_elem.
              lv_cell = |{ <lv_field> }|.
              IF ls_comp-type->type_kind = cl_abap_typedescr=>typekind_int OR
                 ls_comp-type->type_kind = cl_abap_typedescr=>typekind_int8.
                lv_type = `Number`.
              ENDIF.
            WHEN cl_abap_datadescr=>kind_table.
              ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_row> TO <lt_nest>.
              IF sy-subrc = 0.
                lv_cell = |{ lines( <lt_nest> ) }|.
                lv_type = `Number`.
              ENDIF.
            WHEN OTHERS.
              lv_cell = ''.
          ENDCASE.

          rv_xml = rv_xml && `<Cell><Data ss:Type="` && lv_type && `">` &&
                   zcl_ark_convert=>escape_html( iv_text = lv_cell ) && `</Data></Cell>`.
        ENDLOOP.
        rv_xml = rv_xml && `</Row>`.
      ENDLOOP.
    ENDIF.

    rv_xml = rv_xml && `</Table></Worksheet></Workbook>`.
  ENDMETHOD.

ENDCLASS.
