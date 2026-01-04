# v0.1.2

Changes over v0.1.1:
* Fixed moonlight not casting GI
* Improved the look of GI when Sunlight GI Quality is set to 0
* Added new options: 
  * Atmospherics & Lighting > Sun Size: This is a multiplier for the size of the sun sprite in the sky.
  * Diffuse Lighting > Minimum Light: Adds some lighting in caves to improve visibility.
* Fixed NaN issue with reflection filtering
* Added recursive reflection tracing. The amount of reflection bounces can be configured at Reflections > Reflection Bounces
* Added smooth sunlight fade in/out during sunrise/sunset
* Implemented smooth transition between screen-space and irradiance cached lighting in reflections
* Added camera effects: motion blur & depth of field
* Improved shadow denoising

# v0.1.1

Changes over v0.1:
* Added basic water fog
* Improved diffuse temporal & spatial denoising
* Added new options:
  * Diffuse Lighting > Denoising Passes: The amount of denoising passes used for diffuse lighting.
  * Water Absorption: Controls the amount of water light absorption. Higher values make water more dense.
  * Water Reflectance: The strength of reflections on water.
  * Rayleigh Amount: The amount of rayleigh scattering in the atmosphere.
* Basic nether and end support
* Improved TAA on translucent surfaces
* Improved the look of the irradiance cache debug view