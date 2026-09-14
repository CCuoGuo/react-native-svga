/**
 * Jest 白盒单元测试配置。
 *
 * 仅面向 JS 层纯逻辑（src/index.tsx 与 specs），不依赖鸿蒙设备：
 * - ts-jest 直接用仓库 tsconfig 编译测试文件，绕开 Metro 的
 *   babel.config.js（@react-native/babel-preset 依赖 RN 运行时环境）；
 * - react-native / resolveAssetSource / codegen spec 均在测试文件内
 *   jest.mock 隔离，node 环境即可运行。
 */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: './',
  // 测试统一放在 jest/__tests__；扫描范围限定，避免误扫 example/oh_modules
  roots: ['<rootDir>/jest'],
  testMatch: ['<rootDir>/jest/__tests__/*-test.ts'],
  testPathIgnorePatterns: ['/node_modules/', '/oh_modules/'],
  collectCoverageFrom: ['src/**/*.{ts,tsx}', '!src/**/*.d.ts'],
};
