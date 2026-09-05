CLASS zcl_ark_html_table DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_gui_renderable .

    CLASS-METHODS create
      IMPORTING !iv_id TYPE string OPTIONAL
                !iv_class TYPE string DEFAULT 'ark-table'
      RETURNING VALUE(ri_table) TYPE REF TO zcl_ark_html_table .

    "! Fill the builder from any internal table via RTTI: one column per
    "! component (DDIC medium/short/reptext as header, field name as
    "! fallback), numeric columns right-aligned, date/time in user format,
    "! deep table columns show their row count, values HTML-escaped.
    "! Elementary line types render as a single TABLE_LINE column.
    "! The generated table is interactive out of the box: click a column
    "! header to sort (numeric/date aware), type in the filter bar to
    "! filter rows client-side; it sizes to its content and scrolls
    "! horizontally instead of stretching the page.
    "! Returns the configured builder, so add_column/set_striped/... still
    "! apply before render( )
    CLASS-METHODS from_any_table
      IMPORTING !it_table TYPE ANY TABLE
      RETURNING VALUE(ri_table) TYPE REF TO zcl_ark_html_table .

    "! Column header for a structure component: DDIC scrtext_m >
    "! scrtext_s > reptext, field name as fallback. Shared by
    "! from_any_table( ) and external exporters (Excel etc.)
    CLASS-METHODS ddic_header
      IMPORTING
        !is_comp TYPE cl_abap_structdescr=>component
      RETURNING VALUE(rv_text) TYPE string .

    METHODS constructor
      IMPORTING !iv_id TYPE string OPTIONAL
                !iv_class TYPE string DEFAULT 'ark-table' .

    METHODS add_column
      IMPORTING !iv_header TYPE string
                !iv_width TYPE string OPTIONAL
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_table .

    METHODS add_row
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_table .

    METHODS add_cell
      IMPORTING !iv_value TYPE string OPTIONAL
                !ii_html TYPE REF TO zif_ark_html OPTIONAL
                !iv_style TYPE string OPTIONAL
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_table .

    METHODS add_header_row
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_table .

    METHODS add_header_cell
      IMPORTING !iv_value TYPE string OPTIONAL
                !ii_html TYPE REF TO zif_ark_html OPTIONAL
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_table .

    METHODS set_striped IMPORTING !iv_striped TYPE abap_bool DEFAULT abap_true .
    METHODS set_hover IMPORTING !iv_hover TYPE abap_bool DEFAULT abap_true .

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_column,
        header    TYPE string,
        width     TYPE string,
        "! 数据表排序键类型：'n' = 数值列（右对齐 + 数值排序），' ' = 文本
        sort_kind TYPE c LENGTH 1,
      END OF ty_column .
    TYPES tt_component TYPE cl_abap_structdescr=>component_table .
    " type_kind 属性的值域（cl_abap_typedescr=>typekind_* 常量为 C(1)）；
    " 不直接用 cl_abap_typedescr=>typekind 命名类型：其来源是 ABAPTYPE
    " 类型组，经类名寻址在各发行版上不可靠
    TYPES ty_typekind TYPE c LENGTH 1 .
    TYPES:
      BEGIN OF ty_cell,
        value    TYPE string,
        html     TYPE REF TO zif_ark_html,
        style    TYPE string,
        "! 数据表排序键：日期取内部 YYYYMMDD、数值原样、文本即显示值，
        "! 与显示文本分离（用户格式日期无法字典序排序）
        sort_key TYPE string,
      END OF ty_cell .
    TYPES:
      BEGIN OF ty_row, cells TYPE STANDARD TABLE OF ty_cell WITH DEFAULT KEY,
      END OF ty_row .

    DATA mo_html TYPE REF TO zcl_ark_html .
    DATA mt_columns TYPE STANDARD TABLE OF ty_column .
    DATA mt_rows TYPE STANDARD TABLE OF ty_row .
    DATA mt_header_row TYPE STANDARD TABLE OF ty_cell .
    DATA mv_id TYPE string .
    DATA mv_class TYPE string .
    DATA mv_striped TYPE abap_bool VALUE abap_true .
    DATA mv_hover TYPE abap_bool VALUE abap_true .
    DATA mv_current_row TYPE i VALUE 0 .
    "! 数据表模式（from_any_table 置位）：可排序列头 + 筛选条 +
    "! 自然宽度滚动容器；手工构建的表保持原样
    DATA mv_data_mode TYPE abap_bool VALUE abap_false ##NO_TEXT.
    "! 数据表 id 序列：同页多表各自唯一，供前端筛选定位
    CLASS-DATA gv_data_seq TYPE i VALUE 0 ##NO_TEXT.

    METHODS build_table
      RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html
      RAISING zcx_ark_exception .

    "! Flatten a structure's components; .INCLUDE components contribute
    "! their nested components instead of appearing as one deep column.
    "! Static: called from the static from_any_table( ) and touching no
    "! instance state
    CLASS-METHODS collect_components
      IMPORTING
        !io_struct TYPE REF TO cl_abap_structdescr
      CHANGING
        !ct_comp TYPE tt_component .

    "! Elementary value as display string; initial date/time -> empty.
    "! Static: called from the static from_any_table( )
    CLASS-METHODS format_elem_value
      IMPORTING
        !iv_type_kind TYPE ty_typekind
        !ig_value TYPE any
      RETURNING VALUE(rv_text) TYPE string .

    "! Whether a type_kind is one of the numeric kinds. Static like the
    "! other from_any_table( ) helpers
    CLASS-METHODS is_numeric_kind
      IMPORTING
        !iv_kind TYPE ty_typekind
      RETURNING VALUE(rv_yes) TYPE abap_bool .

    "! Client-side sort/filter script (ES5, MSHTML and Edge compatible).
    "! Same function names re-emitted per table: identical bodies, harmless
    CLASS-METHODS sort_filter_js
      RETURNING VALUE(rv_js) TYPE string .
ENDCLASS.

CLASS zcl_ark_html_table IMPLEMENTATION.

  METHOD constructor.
    mo_html = zcl_ark_html=>create( ).
    mv_id = iv_id.
    mv_class = iv_class.
  ENDMETHOD.

  METHOD create.
    CREATE OBJECT ri_table
      EXPORTING
        iv_id    = iv_id
        iv_class = iv_class.
  ENDMETHOD.

  METHOD from_any_table.
    DATA lo_tabledesc TYPE REF TO cl_abap_tabledescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lt_comp TYPE tt_component.
    DATA ls_comp TYPE cl_abap_structdescr=>component.
    DATA ls_col TYPE ty_column.
    DATA ls_cell TYPE ty_cell.
    DATA lv_val TYPE string.
    DATA lv_style TYPE string.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_field> TYPE any.
    FIELD-SYMBOLS <lt_nest> TYPE ANY TABLE.
    FIELD-SYMBOLS <ls_trow> TYPE ty_row.

    " 数据表模式：可排序列头 + 筛选条 + 自然宽度滚动容器。
    " id 会话内递增：同页多表各自唯一，供前端筛选定位
    gv_data_seq = gv_data_seq + 1.

    CREATE OBJECT ri_table
      EXPORTING
        iv_id    = |ARKDT{ gv_data_seq }|
        iv_class = 'ark-table ark-data-table'.

    ri_table->mv_data_mode = abap_true.

    TRY.
        lo_tabledesc ?= cl_abap_tabledescr=>describe_by_data( it_table ).
      CATCH cx_sy_move_cast_error.
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

    IF lo_struct IS NOT BOUND.
      " 行类型非结构：单列 TABLE_LINE。仅基本类型可安全转字符串，
      " 引用/内表等深层行类型降级为占位符
      CLEAR ls_col.
      ls_col-header = 'TABLE_LINE'.
      IF lo_line->kind = cl_abap_typedescr=>kind_elem AND
         is_numeric_kind( lo_line->type_kind ) = abap_true.
        ls_col-sort_kind = 'n'.
      ENDIF.
      APPEND ls_col TO ri_table->mt_columns.

      LOOP AT it_table ASSIGNING <ls_row>.
        APPEND INITIAL LINE TO ri_table->mt_rows ASSIGNING <ls_trow>.
        CLEAR ls_cell.
        IF lo_line->kind = cl_abap_typedescr=>kind_elem.
          ls_cell-value    = zcl_ark_convert=>escape_html( |{ <ls_row> }| ).
          ls_cell-sort_key = |{ <ls_row> }|.
          IF ls_col-sort_kind = 'n'.
            ls_cell-style = 'text-align:right;'.
          ENDIF.
        ELSE.
          ls_cell-value = '…'.
        ENDIF.
        APPEND ls_cell TO <ls_trow>-cells.
      ENDLOOP.
      RETURN.
    ENDIF.

    collect_components( EXPORTING io_struct = lo_struct
                        CHANGING  ct_comp  = lt_comp ).

    LOOP AT lt_comp INTO ls_comp.
      CLEAR ls_col.
      ls_col-header = ddic_header( is_comp = ls_comp ).
      IF ls_comp-type->kind = cl_abap_datadescr=>kind_elem AND
         is_numeric_kind( ls_comp-type->type_kind ) = abap_true.
        ls_col-sort_kind = 'n'.
      ENDIF.
      APPEND ls_col TO ri_table->mt_columns.
    ENDLOOP.

    LOOP AT it_table ASSIGNING <ls_row>.
      APPEND INITIAL LINE TO ri_table->mt_rows ASSIGNING <ls_trow>.
      LOOP AT lt_comp INTO ls_comp.
        " lv_val 必须逐格清空：深层列 ASSIGN 失败的分支不赋值，
        " 残留上一格的值会张冠李戴
        CLEAR: ls_cell, lv_style, lv_val.
        ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_row> TO <lv_field>.
        IF sy-subrc <> 0.
          APPEND ls_cell TO <ls_trow>-cells.
          CONTINUE.
        ENDIF.

        CASE ls_comp-type->kind.
          WHEN cl_abap_datadescr=>kind_elem.
            " 显示文本按类型格式化（日期用户格式）；排序键取内部形态
            " （日期 YYYYMMDD 可字典序），文本排序前端忽略大小写
            lv_val = format_elem_value( iv_type_kind = ls_comp-type->type_kind
                                        ig_value     = <lv_field> ).
            ls_cell-sort_key = |{ <lv_field> }|.
            " 数值列右对齐（Fiori 列表报告惯例）
            IF is_numeric_kind( ls_comp-type->type_kind ) = abap_true.
              lv_style = 'text-align:right;'.
            ENDIF.
          WHEN cl_abap_datadescr=>kind_table.
            " 深层内表列只显示行数
            ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_row> TO <lt_nest>.
            IF sy-subrc = 0.
              lv_val = |{ lines( <lt_nest> ) }|.
              ls_cell-sort_key = lv_val.
              lv_style = 'text-align:right;'.
            ENDIF.
          WHEN OTHERS.
            lv_val = '…'.
        ENDCASE.

        " td() 不转义，单元格值统一过 escape_html 防 HTML 注入/错乱
        ls_cell-value = zcl_ark_convert=>escape_html( lv_val ).
        ls_cell-style = lv_style.
        APPEND ls_cell TO <ls_trow>-cells.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD is_numeric_kind.
    CASE iv_kind.
      WHEN cl_abap_typedescr=>typekind_int1      OR
           cl_abap_typedescr=>typekind_int2      OR
           cl_abap_typedescr=>typekind_int       OR
           cl_abap_typedescr=>typekind_int8      OR
           cl_abap_typedescr=>typekind_packed    OR
           cl_abap_typedescr=>typekind_float     OR
           cl_abap_typedescr=>typekind_decfloat16 OR
           cl_abap_typedescr=>typekind_decfloat34.
        rv_yes = abap_true.
      WHEN OTHERS.
        rv_yes = abap_false.
    ENDCASE.
  ENDMETHOD.

  METHOD sort_filter_js.
    " 前端就地排序/筛选（ES5，IE/MSHTML 与 Edge 双内核兼容），零 ABAP 往返：
    " 排序按单元格 data-v 键（日期内部 YYYYMMDD、数值原样），数值列
    " （th data-kind="n"）按数值比较，否则忽略大小写字典序；
    " 筛选为全表子串匹配，行 display:none 就地隐藏
    rv_js =
      `function arkTblSort(th){var t=th.parentNode.parentNode.parentNode;` &&
      `var tb=t.tBodies[0];if(!tb){return;}` &&
      `var i=th.cellIndex;` &&
      `var dir=th.getAttribute('data-dir')==='asc'?'desc':'asc';` &&
      `var hs=t.tHead.rows[0].cells;` &&
      `for(var j=0;j<hs.length;j++){` &&
      `hs[j].className=hs[j].className.replace(/ark-sorted-\S+/g,'');` &&
      `hs[j].setAttribute('data-dir','');}` &&
      `th.setAttribute('data-dir',dir);` &&
      `th.className=th.className+' '+(dir==='asc'?'ark-sorted-asc':'ark-sorted-desc');` &&
      `var rows=[];for(var j=0;j<tb.rows.length;j++){rows.push(tb.rows[j]);}` &&
      `var num=th.getAttribute('data-kind')==='n';` &&
      `rows.sort(function(a,b){` &&
      `var x=a.cells[i].getAttribute('data-v');` &&
      `var y=b.cells[i].getAttribute('data-v');` &&
      `if(x===null){x=a.cells[i].textContent;}` &&
      `if(y===null){y=b.cells[i].textContent;}` &&
      `if(num){var xa=parseFloat(x),ya=parseFloat(y);` &&
      `if(isNaN(xa)){xa=0;}if(isNaN(ya)){ya=0;}` &&
      `return (xa-ya)*(dir==='asc'?1:-1);}` &&
      `x=(''+x).toLowerCase();y=(''+y).toLowerCase();` &&
      `var r=0;if(x<y){r=-1;}else if(x>y){r=1;}` &&
      `return r*(dir==='asc'?1:-1);});` &&
      `for(var j=0;j<rows.length;j++){tb.appendChild(rows[j]);}}` &&
      `function arkTblFilter(inp,id){` &&
      `var t=document.getElementById(id);` &&
      `if(!t||!t.tBodies[0]){return;}` &&
      `var q=(''+inp.value).toLowerCase();` &&
      `var tb=t.tBodies[0];var n=0;` &&
      `for(var j=0;j<tb.rows.length;j++){` &&
      `var r=tb.rows[j];` &&
      `var s=r.innerText?r.innerText:r.textContent;` &&
      `var hit=(q==='')||((''+s).toLowerCase().indexOf(q)>=0);` &&
      `r.style.display=hit?'':'none';` &&
      `if(hit){n++;}}` &&
      `var c=document.getElementById(id+'_cnt');` &&
      `if(c){c.innerHTML=n+' / '+tb.rows.length;}}`.
  ENDMETHOD.

  METHOD collect_components.
    DATA ls_comp TYPE cl_abap_structdescr=>component.
    DATA lo_nested TYPE REF TO cl_abap_structdescr.

    LOOP AT io_struct->get_components( ) INTO ls_comp.
      " .INCLUDE 组件无独立单元格：递归平铺其子组件（DDIC 表常见 .INCLUDE）
      IF ls_comp-as_include = abap_true AND ls_comp-type IS BOUND
         AND ls_comp-type->kind = cl_abap_typedescr=>kind_struct.
        TRY.
            lo_nested ?= ls_comp-type.
            collect_components( EXPORTING io_struct = lo_nested
                                CHANGING  ct_comp  = ct_comp ).
          CATCH cx_sy_move_cast_error.
            APPEND ls_comp TO ct_comp.
        ENDTRY.
      ELSE.
        APPEND ls_comp TO ct_comp.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ddic_header.
    " 默认用字段名；组件基于 DDIC 数据元素时升级为中/短标签
    DATA lo_elem TYPE REF TO cl_abap_elemdescr.
    DATA ls_dfies TYPE dfies.

    rv_text = is_comp-name.
    IF is_comp-type IS NOT BOUND OR is_comp-type->kind <> cl_abap_datadescr=>kind_elem.
      RETURN.
    ENDIF.

    TRY.
        lo_elem ?= is_comp-type.
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.

    CALL METHOD lo_elem->get_ddic_field
      RECEIVING
        p_flddescr = ls_dfies
      EXCEPTIONS
        not_found    = 1
        no_ddic_type = 2
        OTHERS       = 3.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " 标签逐级回退：中标签 > 短标签 > 标题 > 字段名
    DATA(lv_label) = COND string( WHEN ls_dfies-scrtext_m IS NOT INITIAL THEN ls_dfies-scrtext_m
                                  WHEN ls_dfies-scrtext_s IS NOT INITIAL THEN ls_dfies-scrtext_s
                                  WHEN ls_dfies-reptext    IS NOT INITIAL THEN ls_dfies-reptext
                                  ELSE '' ).
    IF lv_label IS NOT INITIAL.
      rv_text = lv_label.
    ENDIF.
  ENDMETHOD.

  METHOD format_elem_value.
    " 格式化选项要求静态类型：先移入定长目标再套模板，泛型形参不可直接用
    CASE iv_type_kind.
      WHEN cl_abap_typedescr=>typekind_date.
        DATA lv_date TYPE d.
        lv_date = ig_value.
        IF lv_date IS INITIAL.
          rv_text = ''.
        ELSE.
          rv_text = |{ lv_date DATE = USER }|.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_time.
        DATA lv_time TYPE t.
        lv_time = ig_value.
        IF lv_time IS INITIAL.
          rv_text = ''.
        ELSE.
          rv_text = |{ lv_time TIME = USER }|.
        ENDIF.
      WHEN OTHERS.
        rv_text = |{ ig_value }|.
    ENDCASE.
  ENDMETHOD.

  METHOD add_column.
    DATA ls_column TYPE ty_column.
    ls_column-header = iv_header.
    ls_column-width = iv_width.
    APPEND ls_column TO mt_columns.
    ri_self = me.
  ENDMETHOD.

  METHOD add_row.
    DATA ls_row TYPE ty_row.
    APPEND ls_row TO mt_rows.
    mv_current_row = lines( mt_rows ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_cell.
    IF mv_current_row = 0 OR mv_current_row > lines( mt_rows ).
      add_row( ).
    ENDIF.

    FIELD-SYMBOLS <ls_row> TYPE ty_row.
    READ TABLE mt_rows INDEX mv_current_row ASSIGNING <ls_row>.
    IF sy-subrc = 0.
      DATA ls_cell TYPE ty_cell.
      ls_cell-value = iv_value.
      ls_cell-html = ii_html.
      ls_cell-style = iv_style.
      APPEND ls_cell TO <ls_row>-cells.
    ENDIF.
    ri_self = me.
  ENDMETHOD.

  METHOD add_header_row.
    CLEAR mt_header_row.
    ri_self = me.
  ENDMETHOD.

  METHOD add_header_cell.
    DATA ls_cell TYPE ty_cell.
    ls_cell-value = iv_value.
    ls_cell-html = ii_html.
    APPEND ls_cell TO mt_header_row.
    ri_self = me.
  ENDMETHOD.

  METHOD set_hover.
    mv_hover = iv_hover.
  ENDMETHOD.

  METHOD set_striped.
    mv_striped = iv_striped.
  ENDMETHOD.

  METHOD build_table.
    DATA lo_table TYPE REF TO zcl_ark_html.
    lo_table = zcl_ark_html=>create( ).

    DATA lv_id TYPE string.
    IF mv_id IS NOT INITIAL.
      lv_id = | id="{ mv_id }"|.
    ENDIF.

    IF mv_data_mode = abap_true.
      " 筛选条 + 滚动容器：表格按内容自然宽度、超宽横向滚动，
      " 不再拉伸整页；排序/筛选全在前端就地完成，无 ABAP 往返
      lo_table->add( |<div class="ark-filterbar">| ).
      lo_table->add( |<input type="text" placeholder="筛选…"| &&
                    | onkeyup="arkTblFilter(this,'{ mv_id }')">| ).
      lo_table->add( |<span class="ark-tbl-count" id="{ mv_id }_cnt">| &&
                    |共 { lines( mt_rows ) } 行</span>| ).
      lo_table->add( |</div>| ).
      lo_table->add( |<div class="ark-data-wrap">| ).
      lo_table->add_js( sort_filter_js( ) ).
    ENDIF.

    lo_table->add( |<table class="{ mv_class }"{ lv_id }>| ).

    " Header
    IF lines( mt_header_row ) > 0 OR lines( mt_columns ) > 0.
      lo_table->add( |<thead><tr>| ).

      IF lines( mt_header_row ) > 0.
        LOOP AT mt_header_row INTO DATA(ls_hcell).
          IF ls_hcell-html IS NOT INITIAL.
            lo_table->th( ii_content = ls_hcell-html ).
          ELSE.
            lo_table->th( iv_content = ls_hcell-value ).
          ENDIF.
        ENDLOOP.
      ELSE.
        LOOP AT mt_columns INTO DATA(ls_col).
          IF mv_data_mode = abap_true.
            " 可排序列头：点击切换升/降序，箭头随排序状态显示
            DATA(lv_kind_attr) = COND string( WHEN ls_col-sort_kind = 'n'
                                             THEN ` data-kind="n"`
                                             ELSE `` ).
            lo_table->add( |<th class="ark-sortable"{ lv_kind_attr }| &&
                          | onclick="arkTblSort(this)">| &&
                          |{ zcl_ark_convert=>escape_html( ls_col-header ) }</th>| ).
          ELSE.
            lo_table->th( iv_content = ls_col-header ).
          ENDIF.
        ENDLOOP.
      ENDIF.

      lo_table->add( |</tr></thead>| ).
    ENDIF.

    " Body
    lo_table->add( |<tbody>| ).

    LOOP AT mt_rows INTO DATA(ls_row).
      lo_table->add( |<tr>| ).

      LOOP AT ls_row-cells INTO DATA(ls_cell).
        IF mv_data_mode = abap_true AND ls_cell-html IS INITIAL.
          " 数据模式：td 带 data-v 排序键；值已由 from_any_table 转义
          DATA(lv_datav) = COND string( WHEN ls_cell-sort_key IS NOT INITIAL
                                       THEN | data-v="{ zcl_ark_convert=>escape_html( ls_cell-sort_key ) }"|
                                       ELSE `` ).
          DATA(lv_style_attr) = COND string( WHEN ls_cell-style IS NOT INITIAL
                                            THEN | style="{ ls_cell-style }"|
                                            ELSE `` ).
          lo_table->add( |<td{ lv_datav }{ lv_style_attr }>{ ls_cell-value }</td>| ).
        ELSEIF ls_cell-html IS NOT INITIAL.
          lo_table->td( ii_content = ls_cell-html iv_style = ls_cell-style ).
        ELSE.
          lo_table->td( iv_content = ls_cell-value iv_style = ls_cell-style ).
        ENDIF.
      ENDLOOP.

      lo_table->add( |</tr>| ).
    ENDLOOP.

    lo_table->add( |</tbody>| ).
    lo_table->add( |</table>| ).

    IF mv_data_mode = abap_true.
      lo_table->add( |</div>| ).
    ENDIF.

    ri_html = lo_table.
  ENDMETHOD.

  METHOD zif_ark_gui_renderable~render.
    IF lines( mt_rows ) = 0 AND lines( mt_header_row ) = 0 AND lines( mt_columns ) = 0.
      ri_html = zcl_ark_html=>create( ).
      ri_html->add( |<!-- Empty table -->| ).
      RETURN.
    ENDIF.

    ri_html = build_table( ).
  ENDMETHOD.

ENDCLASS.
