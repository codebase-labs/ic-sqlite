# ic-sqlite

SQLite on the Internet Computer, backed by stable memory. Based on [`wasm-sqlite`](https://github.com/rkusa/wasm-sqlite/tree/8af1b8cd59ee28153a3d24c3a73c551c4f272483) and [`icfs`](https://github.com/codebase-labs/icfs).

![](https://img.shields.io/badge/status%EF%B8%8F-incomplete-blueviolet)

## C ABI Compatibility

For most Wasm targets, the ABI used by Rust isn't compatible with the C ABI. This includes `wasm32-unknown-unknown`, the target used by canisters for the Internet Computer.

So, while linking with C can appear to work it can result in hidden memory corruption.

Related issues are rust-lang/rust#83788 and rustwasm/team#291.

[c2rust](https://c2rust.com) may provide a potential path forward.
