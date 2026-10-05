import { makeBackend } from "../_shared/supabase_backend.ts";
import { handle } from "./handler.ts";

const backend = makeBackend();
Deno.serve((req: Request) => handle(req, backend));
