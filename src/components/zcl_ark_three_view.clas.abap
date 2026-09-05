CLASS zcl_ark_three_view DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " three.js 3D 视图组件：zif_ark_js_widget 插件形态的参照实现
    " （除 echarts 外的第二个样板）。实验性：仅验证 WebView2 WebGL 管道。
    INTERFACES zif_ark_js_widget .
    ALIASES render FOR zif_ark_gui_renderable~render .

    CONSTANTS c_lib_name TYPE string VALUE 'three' .
    CONSTANTS c_bundled_mime_name TYPE wwwdatatab-objid VALUE 'ZARK_THREE_MIN_JS' .
    CONSTANTS c_cdn_url TYPE string VALUE 'https://cdn.jsdelivr.net/npm/three@0.149.0/build/three.min.js' .

    METHODS constructor
      IMPORTING
        !iv_div_id TYPE string OPTIONAL
        !iv_height TYPE i DEFAULT 420 .

    "! 注册 three.js 库（会话级一次即可）：缺省读 SMW0 的 UMD 构建
    "! （ZARK_THREE_MIN_JS），资产未部署自动回退 CDN。
    "! 注意必须用 UMD 构建 —— ES module 的 import 在 HTML Viewer 的
    "! file:/// 环境下不可靠
    CLASS-METHODS register_default .

    METHODS set_geometry
      IMPORTING
        !iv_geometry   TYPE string DEFAULT 'box'
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_ark_three_view .

    "! 十六进制色（如 '#0070f2'），进 JS 字面量前经 escape_js
    METHODS set_color
      IMPORTING
        !iv_color      TYPE string
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_ark_three_view .

    "! 画布点击 → sapevent（经公共桥 arkEmit，参数 x/y/唯一无业务语义）
    METHODS set_on_click
      IMPORTING
        !iv_action     TYPE string
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_ark_three_view .

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mv_div_id TYPE string .
    DATA mv_height TYPE i .
    DATA mv_geometry TYPE string .
    DATA mv_color TYPE string .
    DATA mv_on_click TYPE string .
    CLASS-DATA gv_instance_counter TYPE i .
ENDCLASS.



CLASS zcl_ark_three_view IMPLEMENTATION.


  METHOD constructor.
    gv_instance_counter = gv_instance_counter + 1.

    mv_div_id   = COND #( WHEN iv_div_id IS INITIAL
                          THEN |ark_three_{ gv_instance_counter }|
                          ELSE iv_div_id ).
    mv_height   = iv_height.
    mv_geometry = 'box'.
    mv_color    = '#0070f2'.
  ENDMETHOD.


  METHOD register_default.
    IF zcl_ark_js_library=>is_registered( c_lib_name ) = abap_true.
      RETURN.
    ENDIF.
    TRY.
        zcl_ark_js_library=>register(
          iv_name = c_lib_name
          iv_mime = c_bundled_mime_name ).
      CATCH zcx_ark_exception.
        " MIME 资产未部署：回退 CDN（内网环境会退化为容器提示，见 render）
        zcl_ark_js_library=>register(
          iv_name = c_lib_name
          iv_url  = c_cdn_url ).
    ENDTRY.
  ENDMETHOD.


  METHOD set_geometry.
    mv_geometry = iv_geometry.
    ro_self = me.
  ENDMETHOD.


  METHOD set_color.
    mv_color = iv_color.
    ro_self = me.
  ENDMETHOD.


  METHOD set_on_click.
    mv_on_click = iv_action.
    ro_self = me.
  ENDMETHOD.


  METHOD zif_ark_js_widget~get_assets.
    APPEND c_lib_name TO rt_assets.
  ENDMETHOD.


  METHOD zif_ark_gui_renderable~render.
    DATA(lo_html) = zcl_ark_html=>create( ).

    " 依赖自注入：render 前把声明的 JS 库先行输出（页面级 include_for
    " 再调一次也无妨 —— 注册器按页面作用域去重，只出一份 <script>）
    lo_html->add( zcl_ark_js_library=>include_for( me ) ).

    lo_html->div(
      iv_id    = mv_div_id
      iv_style = |width: 100%; height: { mv_height }px;| ).

    " 公共事件桥先行注入（点击回传的 arkEmit 依赖它；同页幂等）
    lo_html->add( zcl_ark_js_bridge=>script( ) ).

    " 几何体构造器映射（受控集合，escape_js 后进 JS）
    DATA(lv_ctor) = SWITCH string( mv_geometry
      WHEN 'sphere'     THEN |new THREE.SphereGeometry(1, 48, 32)|
      WHEN 'torus_knot' THEN |new THREE.TorusKnotGeometry(0.9, 0.28, 160, 24)|
      ELSE |new THREE.BoxGeometry(1.4, 1.4, 1.4)| ).

    DATA lv_click_js TYPE string.
    IF mv_on_click IS NOT INITIAL.
      lv_click_js =
        |canvas.addEventListener('click', function(ev) \{| &&
        zcl_ark_js_bridge=>emit_js(
          iv_action    = mv_on_click
          iv_params_js = |x: ev.offsetX, y: ev.offsetY| ) &&
        |;\});|.
    ENDIF.

    lo_html->add_js(
      |(function() \{| &&
      |var el = document.getElementById('{ zcl_ark_convert=>escape_js( mv_div_id ) }');| &&
      |if (!el) \{ return; \}| &&
      |if (typeof THREE === 'undefined') \{| &&
      |el.innerHTML = '<div style="padding:16px;color:#b91c1c;font-family:sans-serif;">| &&
      |three.js 库脚本未执行（SMW0 缺 ZARK_THREE_MIN_JS 时已回退 CDN 且不可达，| &&
      |或脚本加载报错）。kernel: ' + navigator.userAgent + '</div>';| &&
      |return;| &&
      |\}| &&
      |var renderer;| &&
      |try \{| &&
      |renderer = new THREE.WebGLRenderer(\{ antialias: true, alpha: true \});| &&
      |\} catch (e) \{| &&
      |el.innerHTML = '<div style="padding:16px;color:#b91c1c;font-family:sans-serif;">| &&
      |WebGL 不可用（IE 内核/无 GPU/RDP 远程会话均会导致）: ' + (e && e.message ? e.message : e) +| &&
      |'<br>kernel: ' + navigator.userAgent + '</div>';| &&
      |return;| &&
      |\}| &&
      |renderer.setSize(el.clientWidth, el.clientHeight);| &&
      |el.appendChild(renderer.domElement);| &&
      |var scene = new THREE.Scene();| &&
      |var camera = new THREE.PerspectiveCamera(45, el.clientWidth / el.clientHeight, 0.1, 100);| &&
      |camera.position.set(0, 1.2, 4);| &&
      |camera.lookAt(0, 0, 0);| &&
      |var mesh = new THREE.Mesh(| &&
      lv_ctor &&
      |, new THREE.MeshStandardMaterial(\{ color: '{ zcl_ark_convert=>escape_js( mv_color ) }' \}));| &&
      |scene.add(mesh);| &&
      |scene.add(new THREE.AmbientLight(0xffffff, 0.4));| &&
      |var key = new THREE.DirectionalLight(0xffffff, 0.9);| &&
      |key.position.set(3, 5, 4);| &&
      |scene.add(key);| &&
      |(function animate() \{| &&
      |requestAnimationFrame(animate);| &&
      |mesh.rotation.x += 0.006;| &&
      |mesh.rotation.y += 0.01;| &&
      |renderer.render(scene, camera);| &&
      |\})();| &&
      |window.addEventListener('resize', function() \{| &&
      |renderer.setSize(el.clientWidth, el.clientHeight);| &&
      |camera.aspect = el.clientWidth / el.clientHeight;| &&
      |camera.updateProjectionMatrix();| &&
      |\});| &&
      lv_click_js &&
      |\})();| ).
  ENDMETHOD.


ENDCLASS.
