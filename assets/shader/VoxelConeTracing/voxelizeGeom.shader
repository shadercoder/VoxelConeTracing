/*
 Copyright (c) 2012 The VCT Project

  This file is part of VoxelConeTracing and is an implementation of
  "Interactive Indirect Illumination Using Voxel Cone Tracing" by Crassin et al

  VoxelConeTracing is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  VoxelConeTracing is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with VoxelConeTracing.  If not, see <http://www.gnu.org/licenses/>.
*/

/*!
* \author Dominik Lazarek (dominik.lazarek@gmail.com)
* \author Andreas Weinmann (andy.weinmann@gmail.com)
*/

#version 420

layout(triangles) in;
layout (triangle_strip, max_vertices=3) out;

in VertexData {
    vec3 pos;
    vec3 normal;
    vec2 uv;
} In[3];

out VoxelData {
    vec3 posTexSpace;
    vec3 normal;
    vec2 uv;
    vec3 projAxisTS;
} Out;

out VoxelUtilData {
  flat uint projAxisIdx;
} UtilOut;

uniform mat4 voxelGridTransform;
uniform mat4 voxelGridTransformI;

// Constants for the projection planes to key into the worldAxes array
const uint YZ = 0;
const uint XZ = 1;
const uint XY = 2;

// Constants to key into worldaxes
const uint X = 0;
const uint Y = 1;
const uint Z = 2;

const vec3 worldAxes[3] = vec3[3]( vec3(1.0, 0.0, 0.0),
                                   vec3(0.0, 1.0, 0.0),
                                   vec3(0.0, 0.0, 1.0) );

mat4 viewProjs[3];

void init() {
  vec3 voxelGridSize = vec3(length(voxelGridTransform[0].xyz) * 2.0,
                            length(voxelGridTransform[1].xyz) * 2.0,
                            length(voxelGridTransform[2].xyz) * 2.0);

  // TODO: We need 3 different projection matrices if the voxelGrid is not cubical
  mat4 camProjMatrix = mat4(2.0 / voxelGridSize.x, 0, 0, 0,
                            0, 2.0 / voxelGridSize.y, 0, 0,
                            0, 0, - 2.0 / voxelGridSize.z, 0,
                            0, 0, 0, 1);

  vec3 camPositions[3] = vec3[3] ( vec3(1.0), vec3(1.0), vec3(1.0) );
  camPositions[0] = (voxelGridTransform * vec4(1.0, 0.0, 0.0, 1.0)).xyz;  // Right
  camPositions[1] = (voxelGridTransform * vec4(0.0, 1.0, 0.0, 1.0)).xyz;   // Top
  camPositions[2] = (voxelGridTransform * vec4(0.0, 0.0, 1.0, 1.0)).xyz;  // Far

  mat4 viewMats[3] = mat4[3]( mat4(1.0),    // Right
                              mat4(1.0),    // Top
                              mat4(1.0) );  // Far

  // View Matrix for right camera
  //                    X     y    z
  viewMats[0][0] = vec4(0.0, 0.0, 1.0, 0.0);
  viewMats[0][1] = vec4(0.0, 1.0, 0.0, 0.0);
  viewMats[0][2] = vec4(1.0, 0.0, 0.0, 0.0);
  viewMats[0][3] = vec4(dot(viewMats[0][0].xyz, -camPositions[0]),
                        dot(viewMats[0][1].xyz, -camPositions[0]),
                        dot(viewMats[0][2].xyz, -camPositions[0]), 1.0);

  // View Matrix for top camera
  viewMats[1][0] = vec4(1.0, 0.0, 0.0, 0.0);
  viewMats[1][1] = vec4(0.0, 0.0, 1.0, 0.0);
  viewMats[1][2] = vec4(0.0, 1.0, 0.0, 0.0);
  viewMats[1][3] = vec4(dot(viewMats[1][0].xyz, -camPositions[1]),
                        dot(viewMats[1][1].xyz, -camPositions[1]),
                        dot(viewMats[1][2].xyz, -camPositions[1]), 1.0);


  // View Matrix for far camera
  viewMats[2][0] = vec4(-1.0, 0.0, 0.0, 0.0);
  viewMats[2][1] = vec4(0.0, 1.0, 0.0, 0.0);
  viewMats[2][2] = vec4(0.0, 0.0, 1.0, 0.0);
  viewMats[2][3] = vec4(dot(viewMats[2][0].xyz, -camPositions[2]),
                        dot(viewMats[2][1].xyz, -camPositions[2]),
                        dot(viewMats[2][2].xyz, -camPositions[2]), 1.0);

  viewProjs = mat4[3]( mat4(1.0), mat4(1.0), mat4(1.0) );
  viewProjs[0] = camProjMatrix * viewMats[0];
  viewProjs[1] = camProjMatrix * viewMats[1];
  viewProjs[2] = camProjMatrix * viewMats[2];
}

mat4 lookAt(const in vec3 eye, const in vec3 at, const in vec3 up) {
  /*
  detail::tvec3<T> f = normalize(center - eye);
    detail::tvec3<T> u = normalize(up);
    detail::tvec3<T> s = normalize(cross(f, u));
    u = cross(s, f);

    detail::tmat4x4<T> Result(1);
    Result[0][0] = s.x;
    Result[1][0] = s.y;
    Result[2][0] = s.z;
    Result[0][1] = u.x;
    Result[1][1] = u.y;
    Result[2][1] = u.z;
    Result[0][2] =-f.x;
    Result[1][2] =-f.y;
    Result[2][2] =-f.z;
    Result[3][0] =-dot(s, eye);
    Result[3][1] =-dot(u, eye);
    Result[3][2] = dot(f, eye);
    return Result;
  */

  return mat4(1.0);
}


uint calcProjAxis() {
  // Determine world-axis along wich the projected triangle-area is maximized
  uint projAxis = 0;
  float maxArea = 0.0;
  for (uint i = 0; i < 3; ++i) {
    // Assume we work with per-triangle normals, so that each vertex-normal of
    // one triangle is equal.
    float area = abs(dot(In[0].normal, worldAxes[i]));
    if (area > maxArea) {
      maxArea = area;
      projAxis = i;
    }
  }

  return projAxis;
}

void main()
{
  init();

  uint projAxisIdx = calcProjAxis();
  
  for(int i = 0; i < gl_in.length(); i++) {
    gl_Position = viewProjs[projAxisIdx] * vec4(In[i].pos, 1.0);

    Out.posTexSpace = (voxelGridTransformI * vec4(In[i].pos, 1.0)).xyz * 0.5 + 0.5;
    Out.normal = In[i].normal;
    Out.uv = In[i].uv;
    Out.projAxisTS = normalize((voxelGridTransformI * vec4(worldAxes[projAxisIdx], 0.0)).xyz * 0.5 + 0.5);

    UtilOut.projAxisIdx = projAxisIdx;

    // done with the vertex
    EmitVertex();
  }
  EndPrimitive();
}


/*
 const vec3 projPositions[3] =
        vec3[3]( vec3(0.0, In[i].pos.yz),  // YZ-plane
                 vec3(In[i].pos.x, 0.0, In[i].pos.z),  // XZ-plane
                 vec3(In[i].pos.xy, 0.0) ); // XY-plane
    
    // (TODO) +Z or -Z?
    vec3 clipSpacePos =
      ((In[i].pos - voxelGridOrigin) / voxelGridLength) * 2.0 - 1.0;
    gl_Position = vec4(clipSpacePos, 1.0);
*/
