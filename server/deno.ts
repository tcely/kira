import { serveDir } from "jsr:@std/http/file-server";

Deno.serve((req: Request) => {
    // Serve the current directory by default, or specify a different one with the 'fsRoot' option.
    return serveDir(req, {
        fsRoot: "../dist", // Serves files from the 'dist' directory
        showDirListing: false, // Optional: enables directory listings in the browser
    });
});
