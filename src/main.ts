import {vec2, vec3} from 'gl-matrix';
const Stats = require('stats-js');
import * as DAT from 'dat.gui';
import Square from './geometry/Square';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  'Load Scene': loadScene, // A function pointer, essentially
};

let square: Square;
let time: number = 0;

function loadScene() {
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
  time = 0;
}

function main() {
  window.addEventListener('keypress', function (e) {
    // console.log(e.key);
    switch(e.key) {
      // Use this if you wish
    }
  }, false);

  window.addEventListener('keyup', function (e) {
    switch(e.key) {
      // Use this if you wish
    }
  }, false);

  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI({width: 350});

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 20, -50), vec3.fromValues(0, 0, 60));
  //const camera = new Camera(vec3.fromValues(75, 100, -200), vec3.fromValues(0, 0, 60));
  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(164.0 / 255.0, 233.0 / 255.0, 1.0, 1);
  gl.enable(gl.DEPTH_TEST);

  const shader_water_and_background = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/flat-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/water_and_background-frag.glsl')),
  ]);

  const shader_mountains = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/flat-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/mountains-frag.glsl')),
  ]);

  const shader_castle = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/flat-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/castle-frag.glsl')),
  ]);

  const shader_ridge = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/flat-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/ridge-frag.glsl')),
  ]);

  const shader_right_hill = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/flat-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/right_hill-frag.glsl')),
  ]);

  const shader_left_hill = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/flat-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/left_hill-frag.glsl')),
  ]);

  const shader_bridge = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/flat-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/bridge-frag.glsl')),
  ]);



  function processKeyPresses() {
    // Use this if you wish
  }

  // This function will be called every frame
  function tick() {
    camera.update();
     stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.enable(gl.BLEND);
    processKeyPresses();
    renderer.render(camera, shader_water_and_background, [
      square,
    ], time);

    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.enable(gl.BLEND);
    // clear depth buffer so next passes write over
    gl.clear(gl.DEPTH_BUFFER_BIT);

    renderer.render(camera, shader_mountains, [
      square,
    ], time);

    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.enable(gl.BLEND);

    // clear depth buffer so next passes write over
    gl.clear(gl.DEPTH_BUFFER_BIT);

    renderer.render(camera, shader_castle, [
      square,
    ], time);


    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.enable(gl.BLEND);

    // clear depth buffer so next passes write over
    gl.clear(gl.DEPTH_BUFFER_BIT);

    renderer.render(camera, shader_ridge, [
      square,
    ], time);

    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.enable(gl.BLEND);

    // clear depth buffer so next passes write over
    gl.clear(gl.DEPTH_BUFFER_BIT);

    renderer.render(camera, shader_right_hill, [
      square,
    ], time);

    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.enable(gl.BLEND);

    // clear depth buffer so next passes write over
    gl.clear(gl.DEPTH_BUFFER_BIT);

    renderer.render(camera, shader_left_hill, [
      square,
    ], time);

    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.enable(gl.BLEND);

    // clear depth buffer so next passes write over
    gl.clear(gl.DEPTH_BUFFER_BIT);

    renderer.render(camera, shader_bridge, [
      square,
    ], time);

    time++;
     stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
    shader_water_and_background.setDimensions(window.innerWidth, window.innerHeight);
    shader_mountains.setDimensions(window.innerWidth, window.innerHeight);
    shader_ridge.setDimensions(window.innerWidth, window.innerHeight);
    shader_right_hill.setDimensions(window.innerWidth, window.innerHeight);
    shader_left_hill.setDimensions(window.innerWidth, window.innerHeight);
    shader_bridge.setDimensions(window.innerWidth, window.innerHeight);
    shader_castle.setDimensions(window.innerWidth, window.innerHeight);
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();
  shader_water_and_background.setDimensions(window.innerWidth, window.innerHeight);
  shader_mountains.setDimensions(window.innerWidth, window.innerHeight);
  shader_ridge.setDimensions(window.innerWidth, window.innerHeight);
  shader_right_hill.setDimensions(window.innerWidth, window.innerHeight);
  shader_left_hill.setDimensions(window.innerWidth, window.innerHeight);
  shader_bridge.setDimensions(window.innerWidth, window.innerHeight);
  shader_castle.setDimensions(window.innerWidth, window.innerHeight);

  // Start the render loop
  tick();
}

main();
