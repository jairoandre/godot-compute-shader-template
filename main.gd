extends Node2D

class ShaderResource:
	var img : Image
	var tex : ImageTexture
	var buf : RID
	var uni : RDUniform
	func _init():
		self.img = Image.create(Common.data_texture_size, Common.data_texture_size, false, Image.FORMAT_RGBAF)
		self.tex = ImageTexture.create_from_image(self.img)
	func _update_texture():
		self.tex.update(self.img)
	func _setup_uniform(rd: RenderingDevice, fmt: RDTextureFormat, binding: int):
		self.buf = rd.texture_create(fmt, RDTextureView.new(), [self.img.get_data()])
		self.uni = RDUniform.new()
		self.uni.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		self.uni.binding = binding
		self.uni.add_id(self.buf)
	func _update_uniform(rd: RenderingDevice, fmt: RDTextureFormat):
		self.buf = rd.texture_create(fmt, RDTextureView.new(), [self.img.get_data()])
		self.uni.clear_ids()
		rd.texture_update(self.buf, 0, self.img.get_data())
		self.uni.add_id(self.buf)
	func _read_buffer(rd: RenderingDevice, texture_size: int):
		var image_data = rd.texture_get_data(self.buf, 0)
		self.img = Image.create_from_data(texture_size, texture_size, false, Image.FORMAT_RGBAF, image_data)
		self._update_texture()

var rd = RenderingServer.create_local_rendering_device()
var fmt = RDTextureFormat.new()
var bindings = []
var shader : RID

var shader_resource_1 : ShaderResource
var shader_resource_2 : ShaderResource

func _load_compute_shader(file_name):
	var shader_file = load(file_name) 
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)

func _run_shader():
	var uniform_set = rd.uniform_set_create(bindings, shader, 0)
	var pipeline = rd.compute_pipeline_create(shader)
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	var x_groups = Common.n_particles / 1024
	if Common.n_particles % 1024 > 0:
		x_groups += 1
	rd.compute_list_dispatch(compute_list, x_groups, 1, 1)
	rd.compute_list_end()
	rd.submit()

func _create_params_buffer(delta):
	var vp_rect = get_viewport_rect().size
	var mouse_pos = get_local_mouse_position()
	var mouse_x = mouse_pos.x / vp_rect.x
	var mouse_y = mouse_pos.y / vp_rect.y
	var params_bytes : PackedByteArray = PackedFloat32Array(
		[delta * 0.05, Common.data_texture_size, Common.n_particles, mouse_x, mouse_y]
	).to_byte_array()
	return rd.storage_buffer_create(params_bytes.size(), params_bytes)

func _create_fmt():
	fmt = RDTextureFormat.new()
	fmt.width = Common.data_texture_size
	fmt.height = Common.data_texture_size
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

func _setup_bindings():
	var params_buffer = _create_params_buffer(0)
	var params_uniform = RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform.binding = 0
	params_uniform.add_id(params_buffer)
	bindings = [params_uniform, shader_resource_1.uni, shader_resource_2.uni]

func _update_bindings(delta):
	var params_buffer = _create_params_buffer(delta)
	var params_uniform = bindings[0]
	params_uniform.clear_ids()
	params_uniform.add_id(params_buffer)
	bindings = [params_uniform, shader_resource_1.uni, shader_resource_2.uni]
	
func _setup_particle_shader():
	$GPUParticles2D.amount = Common.n_particles
	$GPUParticles2D.process_material.set_shader_parameter("n_particles", Common.n_particles)
	$GPUParticles2D.process_material.set_shader_parameter("texture_data", shader_resource_1.tex)
	$GPUParticles2D.process_material.set_shader_parameter("scale", 0.05)
	$GPUParticles2D.process_material.set_shader_parameter("texture_data_size", Common.data_texture_size)
	$GPUParticles2D.process_material.set_shader_parameter("vw_size", get_viewport_rect().size)
	
	
# Called when the node enters the scene tree for the first time.
func _ready():
	shader_resource_1 = ShaderResource.new()
	shader_resource_2 = ShaderResource.new()
	for i in Common.data_texture_size:
		for j in Common.data_texture_size:
			var a = randf() * 2 * PI
			shader_resource_1.img.set_pixel(i, j, Color(0.5 + 0.25 * cos(a), 0.5 + 0.25 * sin(a), 0, 0))
			shader_resource_2.img.set_pixel(i, j, Color(randf_range(0.1, 0.9), 0, 0, 0))
	shader_resource_1._update_texture()
	_setup_particle_shader()
	_create_fmt()
	shader_resource_1._setup_uniform(rd, fmt, 1)
	shader_resource_2._setup_uniform(rd, fmt, 2)
	_load_compute_shader("res://shader.glsl")
	_setup_bindings()
	_run_shader()

func _process(delta):
	rd.sync()
	$CanvasLayer/Label.text = "FPS: %d - Particles: %d" % [Engine.get_frames_per_second(), Common.n_particles]
	$GPUParticles2D.process_material.set_shader_parameter("vw_size", get_viewport_rect().size)
	_update_bindings(delta*0.01)
	shader_resource_1._read_buffer(rd, Common.data_texture_size)
	_run_shader()


