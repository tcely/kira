import { serveDir } from "jsr:@std/http/file-server";
import { join } from "jsr:@std/path/posix/join";

const HOST = Deno.env.get("HOST") || "0.0.0.0";
const PORT = parseInt(Deno.env.get("PORT") || "8000");

const operation = Deno.env.get("WHICH") || "server";

if ( "proxy" === operation ) {
    require(join(import.meta.dirname, "..", "proxy", "deno.ts"));
} else {
    Deno.serve(
        {
            hostname: HOST,
            port: PORT,
        },
        (req: Request) => {
            // Serve the current directory by default, or specify a different one with the 'fsRoot' option.
            return serveDir(req, {
                fsRoot: join(import.meta.dirname, "..", "dist"), // Serves files from the 'dist' directory
                showDirListing: false, // Optional: enables directory listings in the browser
            });
        },
    );
}
