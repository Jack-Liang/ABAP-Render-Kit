" 测试用本地 widget：声明两个依赖，其一未注册
CLASS lcl_test_widget DEFINITION FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    " 显式并列声明两个接口：嵌套继承时 render 需双层 ~ 实现，
    " abaplint 解析不了双层 ~，显式声明后两个方法均为单层 ~
    INTERFACES zif_ark_js_widget.
    INTERFACES zif_ark_gui_renderable.
    DATA mv_assets TYPE string_table.
    METHODS set_assets IMPORTING it_assets TYPE string_table.
ENDCLASS.
