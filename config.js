// Conexión a Supabase (la usan index.html y admin.html).
// Copia estos dos valores desde Supabase → Project Settings → API.
// La "anon public key" es pública por diseño: es seguro dejarla aquí.
// Mientras estén vacíos, la página muestra la carta de respaldo que está dentro de index.html.
window.SUPABASE = {
  url: "",      // ej: "https://abcdxyz.supabase.co"
  anonKey: "",  // ej: "eyJhbGciOi..."
};
