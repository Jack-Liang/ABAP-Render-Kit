CLASS zcl_ark_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " 框架保留动作名（ark_ 前缀）的唯一登记处：业务动作不得使用这些名字。
    " 新增保留动作时在此登记，并在对应框架分发点引用本常量
    "! 统一返回（zcl_ark_gui render_page 注入返回条，on_event 最前拦截）
    CONSTANTS c_back     TYPE string VALUE 'ark_back' .
    "! 表格排序（zcl_ark_state_page on_event 内置处理）
    CONSTANTS c_sort     TYPE string VALUE 'ark_sort' .
    "! 表格筛选 POST（zcl_ark_state_page on_event 内置处理）
    CONSTANTS c_filter   TYPE string VALUE 'ark_filter' .
    "! 表格 CSV 下载（zcl_ark_state_page on_event 内置处理）
    CONSTANTS c_download TYPE string VALUE 'ark_download' .
ENDCLASS.

CLASS zcl_ark_actions IMPLEMENTATION.
ENDCLASS.
