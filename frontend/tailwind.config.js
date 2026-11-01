const themeScale = Object.fromEntries(
  [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950].map((k) => [k, `rgb(var(--brand-${k}) / <alpha-value>)`])
);

/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Plus Jakarta Sans"', 'system-ui', '-apple-system', 'Segoe UI', 'Roboto', 'sans-serif'],
      },
      colors: {
        // Theme-driven: values come from CSS variables in theme-tokens.css,
        // so every brand-* AND red-* utility follows the active theme.
        brand: themeScale,
        red: themeScale,
        ink: {
          DEFAULT: 'rgb(var(--ink) / <alpha-value>)',
          800: 'rgb(var(--ink2) / <alpha-value>)',
          700: 'rgb(var(--ink3) / <alpha-value>)',
        },
      },
      boxShadow: {
        soft: '0 8px 24px -8px rgba(15, 23, 42, 0.10)',
        glow: '0 12px 32px -10px rgb(var(--brand-600) / 0.45)',
      },
      transitionTimingFunction: {
        emphasized: 'cubic-bezier(0.2, 0, 0, 1)',
      },
    },
  },
  plugins: [],
};
