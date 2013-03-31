// Generated by CoffeeScript 1.6.1
var Vect, max, min, v;

min = Math.min;

max = Math.max;

Vect = function(x, y) {
  this.x = x;
  this.y = y;
};

v = function(x, y) {
  return new Vect(x, y);
};

if (typeof window !== "undefined" && window !== null) {
  window.v = v;
} else {
  module.exports = v;
}

v.Vect = Vect;

v.add = function(v1, v2) {
  return new Vect(v1.x + v2.x, v1.y + v2.y);
};

v.sub = function(v1, v2) {
  return new Vect(v1.x - v2.x, v1.y - v2.y);
};

v.neg = function(a) {
  return new Vect(-a.x, -a.y);
};

v.mult = function(a, f) {
  return new Vect(a.x * f, a.y * f);
};

v.dot = function(v1, v2) {
  return v1.x * v2.x + v1.y * v2.y;
};

v.dot2 = function(x1, y1, x2, y2) {
  return x1 * x2 + y1 * y2;
};

v.cross = function(v1, v2) {
  return v1.x * v2.y - v1.y * v2.x;
};

v.cross2 = function(x1, y1, x2, y2) {
  return x1 * y2 - y1 * x2;
};

v.lensq = function(a) {
  return v.dot(a, a);
};

v.len = function(a) {
  return Math.sqrt(v.dot(a, a));
};

v.perp = function(a) {
  return new Vect(-a.y, a.x);
};

v.normalize = function(a) {
  return v.mult(a, 1 / v.len(a));
};

v.rotate = function(v1, v2) {
  return new Vect(v1.x * v2.x - v1.y * v2.y, v1.x * v2.y + v1.y * v2.x);
};

v.rotate2 = function(x, y, a) {
  return new Vect(x * a.x - y * a.y, x * a.y + y * a.x);
};

v.unrotate = function(v1, v2) {
  return new Vect(v1.x * v2.x + v1.y * v2.y, v1.y * v2.x - v1.x * v2.y);
};

v.forangle = function(a) {
  return new Vect(Math.cos(a), Math.sin(a));
};

v.clamp = function(f, minv, maxv) {
  return min(max(f, minv), maxv);
};

v.clamp01 = function(f) {
  return min(max(f, 0), 1);
};

v.lerp = function(v1, v2, t) {
  return v(v1.x * (1 - t) + v2.x * t, v1.y * (1 - t) + v2.y * t);
};

v.lerp2 = function(x1, x2, t) {
  return x1 * (1 - t) + x2 * t;
};

v.zero = new Vect(0, 0);