import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.25.0'
import { setting_anon_key, setting_service_role_key, setting_supabase_url } from "./settings.ts";
import { Database } from "../shared/models/database.types.ts";
import ServerRequest from "https://deno.land/x/pogo@v0.6.0/lib/request.ts";
import { decode } from "https://deno.land/x/djwt@v2.9/mod.ts";

export const createSupabaseForCaller = (req:Request | ServerRequest) => createClient<Database>(setting_supabase_url(), setting_anon_key(),
    { auth: { persistSession:false }, global: { headers: { Authorization: req.headers.get('Authorization')! } } }
);

export const createSupabaseForAnon = () => createClient<Database>(setting_supabase_url(), setting_anon_key(), { auth: { persistSession:false }});

export const createSupabaseForServiceRole = () => createClient<Database>(setting_supabase_url(), setting_service_role_key(), { auth: { persistSession:false }});

export const parse_jwt = (req:Request | ServerRequest) => {
    // deno-lint-ignore no-unused-vars
    const [header, payload, signature] = decode(req.headers.get('Authorization')?.replace('Bearer ', '') || '' );
    return payload as IJwt;

}

export interface IJwt {
    aud: string;
    exp: number;
    sub: string;
    email: string;
    phone: string;
    app_metadata: IAppMetadata;
    user_metadata: IUserMetadata;
    unique_ident: string;
    role: string;
    key_type: string;
}
export interface IAppMetadata {
    organization_id: string;
}

export interface IUserMetadata {
    name: string;
}