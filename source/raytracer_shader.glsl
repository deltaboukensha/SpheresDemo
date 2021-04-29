#version 330
#ifdef VERT
layout(location = 0) in vec2 position;
layout(location = 1) in vec2 texcoord;
out vec2 st;

void main()
{
	gl_Position = vec4(position, 0, 1);
	st = texcoord;
}
#endif

#ifdef FRAG
#define focal_length 4
#define sphere_count 5
#define light_count 2
#define float_max 1000000000.0f
#define ray_count_max 8
#define background_illumination vec3(1, 1, 1)

vec3 sphere_position[sphere_count] = vec3[](
	vec3(+4, 0, 0), vec3(-10, 0, 3), vec3(0, -10, 6), vec3(0, +10, 9), vec3(0, 0, 100)
	//, vec3(0, 0, -10), vec3(0, 0, -10), vec3(0, 0, -10)
);

const float sphere_radius[sphere_count] = float[](
	2, 3, 7, 10, 80
	//, .1, .1, .1
);

const vec3 sphere_color[sphere_count] = vec3[](
	vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1), vec3(1, 1, 0), vec3(0, 1, 1)
	//,vec3(1,1,1), vec3(1,1,1), vec3(1,1,1)
);

const vec3 light_position[light_count] = vec3[](
	vec3(0, 0, 0), vec3(0, 0, 0)
);

const vec3 light_illumination[light_count] = vec3[](
	vec3(1, 1, 1), vec3(0, 0, 0)
);

const vec3 plane_position = vec3(0, 0, 0);
const vec3 plane_normal_unit = vec3(0, 0, 1);

uniform vec3 camera_position;
uniform mat3 camera_rotation;
uniform sampler2D sampler0;
uniform sampler2D sampler1;
uniform sampler2D sampler2;
uniform sampler2D sampler3;
uniform sampler2D sampler4;
uniform sampler2D sampler5;

in vec2 st;
out vec4 frag_color;

//todo verify this code
void closest_intersect_plane(vec3 ray_position, vec3 ray_direction, inout float hit_ray_t, inout int plane_index)
{
	float rd_dot_pn = dot(normalize(ray_direction), plane_normal_unit);
	plane_index = -1;
	
	if(1e-6 < rd_dot_pn)
	{
		//there is exactly one intersection point
		hit_ray_t = dot(normalize(plane_position - ray_position), plane_normal_unit) / rd_dot_pn;
		
		if(hit_ray_t >= 0)
		{
			vec3 intersection_position = hit_ray_t * ray_direction + ray_position;
			if(-1 < intersection_position.x && intersection_position.x < +1 && -1 < intersection_position.y && intersection_position.y < +1)
				plane_index = 0;
		}
	}
}

//intersection test, find which sphere is the closest hit, returns -1 if no sphere was hit
void closest_hit_sphere(vec3 ray_position, vec3 ray_direction, inout int hit_sphere_index, inout float hit_ray_t)
{
	hit_ray_t = float_max;
	
	for(int sphere_index = 0; sphere_index < sphere_count; sphere_index++)
	{
		float a = dot(ray_direction, ray_direction);
		float b = dot(2.0 * ray_direction, ray_position - sphere_position[sphere_index]);
		float c = dot(ray_position - sphere_position[sphere_index], ray_position - sphere_position[sphere_index]) - sphere_radius[sphere_index] * sphere_radius[sphere_index];
		float d = b * b - 4 * a * c;
		float e = sqrt(d);
		float t0 = (-b + e) / (2 * a);
		float t1 = (-b - e) / (2 * a);

		if(d > 0)
		{
			float t_min = 0.001f;
			float ray_t;
			
			//always two hits, straight through the sphere
			if(t0 <= t_min && t1 <= t_min) //both are behind camera
				continue;
			else if( t0 <= t_min ) //one behind camera
				ray_t = t1;
			else if( t1 <= t_min ) //one behind camera
				ray_t = t0;
			else //choose the closest one
				ray_t = min(t0, t1);
			
			if(ray_t < hit_ray_t)
			{
				hit_ray_t = ray_t;
				hit_sphere_index = sphere_index;
			}
		}
	}
}

void main()
{
	vec3 ray_positions[ray_count_max];
	vec3 ray_directions[ray_count_max];
	float ray_next_mixes[ray_count_max];
	int ray_count = 0;
	
	// //ray refraction debugging
	// {
		// ray_positions[ray_count] = vec3(0, 0, 0);
		// ray_directions[ray_count] = vec3(0, 0, 1);
		// ray_count++;
		// int debug_sphere_index = 0;
		// vec3 debug_sphere_position[3];
		
		// for(int ray_index = 0; ray_index < 3; ray_index++)
		// {
			// vec3 ray_position = ray_positions[ray_index];
			// vec3 ray_direction = ray_directions[ray_index];
			// int hit_sphere_index;
			// float hit_ray_t; 
			// closest_hit_sphere(ray_position, ray_direction, hit_sphere_index, hit_ray_t);
			
			// if(hit_ray_t != -1)
			// {
				// vec3 intersection_position = hit_ray_t * ray_direction + ray_position;
				// debug_sphere_position[debug_sphere_index] = intersection_position;
				// debug_sphere_index++;
				
				// ray_positions[ray_count] = intersection_position;
				// vec3 outward_surface_normal = normalize(intersection_position - sphere_position[hit_sphere_index]);
				
				// if(dot(ray_direction, outward_surface_normal) < 0)
					// ray_directions[ray_count] = refract(normalize(ray_direction), +outward_surface_normal, 1.0f/1.2f);
				// else
					// ray_directions[ray_count] = refract(normalize(ray_direction), -outward_surface_normal, 1.2f/1.0f);
				// //ray_directions[ray_count] = vec3(0, 0, 1);
				// ray_count++;
			// }
		// }
		
		// for(int ia=0; ia<3; ia++)
			// sphere_position[5+ia] = debug_sphere_position[ia];
		
		// ray_count = 0;
	// }
	
	vec3 ray_illumination = background_illumination; //a ray illumination has a color and light intensity described by its colors
	ray_positions[ray_count] = camera_position;
	ray_directions[ray_count] = camera_rotation * vec3(st, focal_length);
	ray_next_mixes[ray_count] = 1.0f;
	ray_count++;
	
	for(int ray_index = 0; ray_index < ray_count_max && ray_index < ray_count; ray_index++)
	{
		vec3 ray_position = ray_positions[ray_index];
		vec3 ray_direction = ray_directions[ray_index];
		float ray_mix = ray_next_mixes[ray_index];

		int hit_sphere_index = -1;
		float hit_ray_t;
		closest_hit_sphere(ray_position, ray_direction, hit_sphere_index, hit_ray_t);
		
		if(hit_sphere_index == -1)
		{
			//missed all objects in scene
			// int hit_plane_index;
			// closest_intersect_plane(ray_position, ray_direction, hit_ray_t, hit_plane_index);
			
			// if(hit_plane_index != -1)
			// {
				// vec3 intersection_position = ray_position + ray_direction * hit_ray_t;
				// ray_illumination = texture2D(sampler0, intersection_position.xy).rgb;
			// }
			// else
			// {
				// //ray_illumination += background_illumination * ray_mix;
				// ray_illumination = mix(ray_illumination, background_illumination, ray_mix);
			// }
		}
		else
		{
			//basic shading
			//ray_illumination += sphere_color[hit_sphere_index];
		
			vec3 intersection_position = hit_ray_t * ray_direction + ray_position;
			vec3 outward_surface_normal = normalize(intersection_position - sphere_position[hit_sphere_index]);
			float facing_ratio = max(0.0, -dot(normalize(ray_direction), outward_surface_normal));
			float fresnel_effect = mix(pow(1. - facing_ratio, 3.), 1., 0.1);
		
			//shade
			//http://en.wikipedia.org/wiki/Phong_reflection_model
			//if(ray_from_outside)
			if(dot(ray_direction, outward_surface_normal) < 0)
			{
				vec3 illumination = vec3(0, 0, 0);
				
				//ambient
				illumination += vec3(0.5) * sphere_color[hit_sphere_index];
				
				for(int light_index = 0; light_index < 1; light_index++)
				{
					vec3 ray_to_light_position = intersection_position;
					vec3 ray_to_light_direction = light_position[light_index] - intersection_position;
					int light_hit_sphere_index;
					float light_hit_ray_t;
					closest_hit_sphere(ray_to_light_position, ray_to_light_direction, light_hit_sphere_index, light_hit_ray_t);
					
					float distance_to_light_squared = ray_to_light_direction.x * ray_to_light_direction.x + ray_to_light_direction.y * ray_to_light_direction.y + ray_to_light_direction.z * ray_to_light_direction.z;
					
					//if(light_hit_sphere_index == -1)
					{
						//the point is illuminated by the light source
						vec3 light_vector = normalize(ray_to_light_direction);
						
						//diffuse
						float diffuse_light_intensity = clamp(dot(outward_surface_normal, light_vector), 0, 1);
						illumination += light_illumination[light_index] * diffuse_light_intensity * 100 * sphere_color[hit_sphere_index] / distance_to_light_squared;
						
						//specular
						vec3 view_vector = normalize(camera_position - intersection_position);
						vec3 reflected_light_vector = normalize(2 * dot(light_vector, outward_surface_normal) * outward_surface_normal - light_vector);
						float specular_light_intensity = pow(clamp(dot(reflected_light_vector, view_vector), 0, 1), 50);
						illumination += light_illumination[light_index] * specular_light_intensity * 1000 / distance_to_light_squared * vec3(1.0f, 1.0f, 1.0f);
						
						//illumination += light_illumination[light_index] * dot(light_vector, outward_surface_normal);
					}
					// else
					// {
						// //something is occluding the light and the point is in the shadowed area
						// //illumination += light_illumination[light_index] * sphere_color[hit_sphere_index] * 0.1f / distance_to_light_squared;
					// }
				}
				
				//ray_illumination += illumination * sphere_color[hit_sphere_index] * ray_mix;
				ray_illumination = mix(ray_illumination, illumination, ray_mix * (1 - fresnel_effect));
			}
		
			// //pushback reflected rays
			// {
				// ray_positions[ray_count] = intersection_position;
				// ray_directions[ray_count] = intersection_position - sphere_position[hit_sphere_index];
				// ray_next_mixes[ray_count] = ray_mix * 0.9f;
				// ray_count++;
			// }
			
			//pushback refracted rays
			{
				ray_positions[ray_count] = intersection_position;
				float sphere_refraction_index = 1.8f;
				
				if(dot(ray_direction, outward_surface_normal) < 0)
				{
					ray_directions[ray_count] = refract(normalize(ray_direction), +outward_surface_normal, 1.0f / sphere_refraction_index);
					ray_next_mixes[ray_count] = ray_mix * 0.5;
				}
				else
				{
					ray_directions[ray_count] = refract(normalize(ray_direction), -outward_surface_normal, sphere_refraction_index / 1.0f);
					ray_next_mixes[ray_count] = ray_mix * 0.5;
				}
				
				ray_count++;
			}
		}
	}

	frag_color = vec4(ray_illumination, 1);
}
#endif
