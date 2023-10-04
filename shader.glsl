#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x=1024,local_size_y=1,local_size_z=1)in;

// A binding to the buffer we create in our script
layout(set=0,binding=0,std430)restrict buffer Params{
  float delta;
  float texture_size;
  float num_particles;
  float mouse_x;
  float mouse_y;
}params;

layout(rgba32f,binding=1)uniform image2D tex_data_1;
layout(rgba32f,binding=2)uniform image2D tex_data_2;

ivec2 one_to_two(int index){
  int grid_size=int(params.texture_size);
  int row=int(index/grid_size);
  int col=index%grid_size;
  return ivec2(col,row);
}

// The code we want to execute in each invocation
void main(){
  int num_particles=int(params.num_particles);
  int index=int(gl_GlobalInvocationID.x);
  if(index>=num_particles){
    return;
  }
  ivec2 coord=one_to_two(index);
  vec4 data_1=imageLoad(tex_data_1,coord);
  vec4 data_2=imageLoad(tex_data_2,coord);
  vec2 pos=data_1.rg;
  vec2 vel=data_1.ba;
  float mass=data_2.r;
  vec2 target=vec2(params.mouse_x,params.mouse_y);
  vec2 desired=target-pos;
  vec2 accel=desired/mass;
  float dt=params.delta;
  float friction=pow(.5,dt/.040);
  vel*=friction;
  vel+=accel*dt;
  if(length(vel)>.0025){
    vel=normalize(vel)*.0025;
  }
  pos+=vel;
  vec4 n_data=vec4(pos,vel);
  imageStore(tex_data_1,coord,n_data);
}
