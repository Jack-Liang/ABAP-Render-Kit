CLASS zcl_ark_texts DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES ty_key TYPE string .

    CONSTANTS:
      BEGIN OF c_key,
        "! 统一返回条（render_page 自动注入）
        back                TYPE ty_key VALUE 'back',
        "! 表格筛选按钮 / 占位符 / CSV 下载链接
        filter              TYPE ty_key VALUE 'filter',
        filter_placeholder  TYPE ty_key VALUE 'filter_placeholder',
        download_csv        TYPE ty_key VALUE 'download_csv',
        "! 表格无匹配行提示
        no_match            TYPE ty_key VALUE 'no_match',
        "! 声明式表单 required 校验失败提示
        required_error      TYPE ty_key VALUE 'required_error',
        "! CSV 下载异常前缀 / 文件对话框过滤器
        csv_download_failed TYPE ty_key VALUE 'csv_download_failed',
        file_filter_csv     TYPE ty_key VALUE 'file_filter_csv',
        "! chart 节库加载失败降级提示
        echarts_missing     TYPE ty_key VALUE 'echarts_missing',
        "! 渲染时无页面（go_home 清空等历史场景）的可见提示
        no_page             TYPE ty_key VALUE 'no_page',
        "! 长动作忙指示遮罩（B2）
        busy                TYPE ty_key VALUE 'busy',
      END OF c_key .

    "! 按当前登录语言取框架界面文本；未收录语言回退英文，未知键返回空串。
    "! 业务页面文本不归本类管——只收框架自带 UI 的固定文案
    CLASS-METHODS text
      IMPORTING
        !iv_key         TYPE ty_key
      RETURNING
        VALUE(rv_text)  TYPE string .

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_text,
        key  TYPE ty_key,
        text TYPE string,
      END OF ty_text,
      tt_text TYPE HASHED TABLE OF ty_text WITH UNIQUE KEY key .
    CLASS-DATA gt_texts TYPE tt_text .
    CLASS-DATA gv_langu TYPE sy-langu .
    CLASS-METHODS load_texts
      IMPORTING
        !iv_langu      TYPE sy-langu
      RETURNING
        VALUE(rt_text) TYPE tt_text .
ENDCLASS.

CLASS zcl_ark_texts IMPLEMENTATION.

  METHOD text.
    " 语言切换只在登录时确定，会话内不变——首载后缓存
    IF gt_texts IS INITIAL OR gv_langu <> sy-langu.
      gt_texts = load_texts( sy-langu ).
      gv_langu = sy-langu.
    ENDIF.
    READ TABLE gt_texts INTO DATA(ls_text) WITH KEY key = iv_key.
    IF sy-subrc = 0.
      rv_text = ls_text-text.
    ENDIF.
  ENDMETHOD.

  METHOD load_texts.
    " 新增键：两套语言表都要补，zcl_ark_texts 单测会对齐完整性
    CASE iv_langu.
      WHEN '1'.  " 中文
        INSERT VALUE #( key = c_key-back                text = '返回' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-filter              text = '筛选' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-filter_placeholder  text = '任意列包含…' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-download_csv        text = '下载 CSV' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-no_match            text = '无匹配数据' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-required_error      text = '此字段为必填项' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-csv_download_failed text = 'CSV 下载失败' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-file_filter_csv     text = 'CSV 文件 (*.csv)|*.csv|所有文件|*.*' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-echarts_missing     text = 'ECharts 库未加载（CDN/MIME 均不可达）— 图表缺席' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-no_page             text = 'ARK：当前无页面（渲染先于 set_page，或页面被清空）' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-busy                text = '处理中…' ) INTO TABLE rt_text.
      WHEN OTHERS.  " 英文（默认回退）
        INSERT VALUE #( key = c_key-back                text = 'Back' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-filter              text = 'Filter' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-filter_placeholder  text = 'Match any column…' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-download_csv        text = 'Download CSV' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-no_match            text = 'No matching data' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-required_error      text = 'This field is required' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-csv_download_failed text = 'CSV download failed' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-file_filter_csv     text = 'CSV files (*.csv)|*.csv|All files|*.*' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-echarts_missing     text = 'ECharts library not loaded (CDN/MIME unreachable) — chart missing' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-no_page             text = 'ARK: no page set (render before set_page / page was cleared)' ) INTO TABLE rt_text.
        INSERT VALUE #( key = c_key-busy                text = 'Working…' ) INTO TABLE rt_text.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
