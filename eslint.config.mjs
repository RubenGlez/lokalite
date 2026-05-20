import nextVitals from 'eslint-config-next/core-web-vitals'
import nextTypescript from 'eslint-config-next/typescript'
import prettier from 'eslint-config-prettier'

const eslintConfig = [
  {
    ignores: [
      'next.config.js',
      'postcss.config.js',
      'prettier.config.js',
      'tailwind.config.ts'
    ]
  },
  ...nextVitals,
  ...nextTypescript,
  prettier,
  {
    rules: {
      'no-unused-vars': 'off',
      '@typescript-eslint/no-unused-vars': 'error',
      'react-hooks/incompatible-library': 'off',
      'react-hooks/preserve-manual-memoization': 'off',
      'react-hooks/purity': 'off',
      'react-hooks/refs': 'off',
      'react-hooks/set-state-in-effect': 'off'
    }
  }
]

export default eslintConfig
