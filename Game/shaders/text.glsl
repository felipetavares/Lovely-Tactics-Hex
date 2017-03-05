
extern vec2 stepSize = vec2(0.001f, 0.001f);
extern vec2 scale = vec2(1, 1);

uniform vec4 outlineColor = vec4(0,0,0,1); // the color of the outline
uniform number outlineSize = 1; // in pixels
uniform number contrast = 30;

vec4 effect( vec4 color, sampler2D texture, vec2 texture_coords, vec2 screen_coords ) {
  vec4 initialColor = texture2D(texture, texture_coords);
  number initialAlpha = initialColor[3];

  // Apply contrast.
  initialColor /= initialAlpha;
  initialColor *= contrast;
  initialColor += vec4(0.5f, 0.5f, 0.5f, 0);
  initialColor[0] = min(initialColor[0] * contrast, 1);
  initialColor[1] = min(initialColor[1] * contrast, 1);
  initialColor[2] = min(initialColor[2] * contrast, 1);
  initialColor *= initialAlpha;
  
  // Calculate alpha in neighborhood.
  number outlineAlpha = 0;
  vec2 offset = stepSize;
  for (number i = -outlineSize*scale.x; i <= outlineSize*scale.x; i += scale.x) {
      for (number j = -outlineSize*scale.y; j <= outlineSize*scale.y; j += scale.y) {
          offset = vec2(i * stepSize.x, j * stepSize.y);
          vec4 neighborColor = texture2D(texture, texture_coords + offset);
          outlineAlpha += neighborColor[3];
      }
  }
  
  // Combine initial and outline colors.
  outlineAlpha = min(outlineAlpha / (outlineSize * outlineSize), 1) * outlineColor[3];
  number finalAlpha = initialAlpha + (1 - initialAlpha) * outlineAlpha;
  vec4 finalColor = (initialAlpha * initialColor + (1 - initialAlpha) * outlineAlpha * outlineColor);
  finalColor[3] = finalAlpha;
  
  return finalColor * color;
}