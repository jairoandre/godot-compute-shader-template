shader_type particles;

uniform sampler2D texture_data;
uniform float n_particles;
uniform float texture_data_size;
uniform vec2 vw_size;
uniform float scale;

void process() {
	
	if (INDEX > uint(n_particles)) {
		COLOR = vec4(0);
	}
	int i = int(mod(float(INDEX),texture_data_size));
	int j = int(INDEX/uint(texture_data_size));
	vec4 part_data = texelFetch(texture_data, ivec2(i, j), 0);
	TRANSFORM[3] = vec4(part_data.r * vw_size.r, part_data.g * vw_size.g, 0., 0.);
	
	mat2 scale_mat = mat2(vec2(scale, 0.), vec2(0., scale));
	TRANSFORM[0].xy = scale_mat[0];
	TRANSFORM[1].xy = scale_mat[1];
	
	// Place process code here.
	COLOR = vec4(vec3(1.), 1.);
	// Place process code here.
}
