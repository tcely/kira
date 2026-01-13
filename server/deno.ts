import { serveDir } from "jsr:@std/http/file-server";

const HOST = Deno.env.get("HOST") || "0.0.0.0";
const PORT = parseInt(Deno.env.get("PORT") || "8000");

Deno.serve(
    {
        hostname: HOST,
        port: PORT,
    },
    (req: Request) => {
        // Serve the current directory by default, or specify a different one with the 'fsRoot' option.
        return serveDir(req, {
            fsRoot: "/dist", // Serves files from the 'dist' directory
            showDirListing: false, // Optional: enables directory listings in the browser
        });
    },
);
