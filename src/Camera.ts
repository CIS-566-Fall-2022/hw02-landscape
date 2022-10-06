import {vec3, mat4} from 'gl-matrix';

class Camera {
  //controls: any;
  projectionMatrix: mat4 = mat4.create();
  viewMatrix: mat4 = mat4.create();
  fovy: number = 45;
  aspectRatio: number = 1;
  near: number = 0.1;
  far: number = 1000;
  position: vec3 = vec3.create();
  direction: vec3 = vec3.create();
  target: vec3 = vec3.create();
  up: vec3 = vec3.create();

  constructor(position: vec3, target: vec3, up: vec3) {
    mat4.lookAt(this.viewMatrix, vec3.fromValues(8, 2, 10), vec3.fromValues(-13, 0, 0), vec3.fromValues(0, 1, 0));
  }

  setAspectRatio(aspectRatio: number) {
    this.aspectRatio = aspectRatio;
  }

  updateProjectionMatrix() {
    mat4.perspective(this.projectionMatrix, this.fovy, this.aspectRatio, this.near, this.far);
  }

  update() {
    mat4.lookAt(this.viewMatrix, vec3.fromValues(8, 2, 10), vec3.fromValues(-13, 0, 0), vec3.fromValues(0, 1, 0));
  }
};

export default Camera;
