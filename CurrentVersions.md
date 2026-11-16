# SPFx generator versions

The Node version each `@microsoft/generator-sharepoint` line was run under, and
the Node range that line supports. Every row was generated with a fresh `yo`
run (dummy names, no work code) into
`generators/spfx-webpart/<version>/`.

| Node (nvm) | Installed | Latest in that line | Node range the generator supports |
| ---------- | --------- | ------------------- | --------------------------------- |
| v18.20.8   | 1.20.0    | 1.20.0              | 18.17.1 up to, not including, 19  |
| v22.21.1   | 1.21.1    | 1.21.1              | 22.14.0 up to, not including, 23  |
| v22.22.0   | 1.22.2    | 1.22.2              | 22.14.0 up to, not including, 23  |
| v22.22.3   | 1.23.0    | 1.23.2              | 22.14.0 up to, not including, 23  |

Generated folders present: `1.20.0`, `1.21.1`, `1.22.2`, `1.23.0`, `1.23.2`.
`node_modules/`, `package-lock.json`, `temp/`, `lib/` and `lib-commonjs/` in
those folders are build output and must be stripped before packing.
