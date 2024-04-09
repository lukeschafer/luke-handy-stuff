import ServerRequest from "https://deno.land/x/pogo@v0.6.0/lib/request.ts";
import ServerResponse from "https://deno.land/x/pogo@v0.6.0/lib/response.ts";
import * as pogo from "https://deno.land/x/pogo@v0.6.0/main.ts";

export class SupaPogo {
    router: pogo.Router;
    functionName: string;
    constructor(functionName:string) {
        this.router = new pogo.Router();
        this.functionName = functionName;
    }

    async handle(req:Request):Promise<Response> {
        const url = new URL(req.url);

        const splitString = '/' + this.functionName + '/';
        const postFnPath = url.pathname.substring(url.pathname.indexOf(splitString)+splitString.length)
        console.log(`${req.method}: /${postFnPath}`);

        const route = this.router.lookup(req.method, postFnPath, url.hostname);

        if (!route) {
            if (req.method == 'OPTIONS') {
                //no OPTIONS route explicitely, so check them
                const verbs = [
                    this.router.lookup('GET', postFnPath, url.hostname),
                    this.router.lookup('POST', postFnPath, url.hostname),
                    this.router.lookup('PUT', postFnPath, url.hostname),
                    this.router.lookup('PATCH', postFnPath, url.hostname),
                    this.router.lookup('DELETE', postFnPath, url.hostname)
                ].filter(x => !!x);
                if (verbs.length) {
                    const verbString = verbs.map(x => x?.method).join(', ');
                    return new Response(null,  { headers: { ...this.cors_headers, Allow: verbString}, status: 200, })
                }

            }
            return this.respond_code(404);
        }

        const serverRequest = new ServerRequest({
            raw    : req,
            route,
            server : {} as pogo.Server //TODO: mimic anything needed?
        });

        try {
            const result = await route.handler(serverRequest, new pogo.Toolkit(serverRequest));
            if (result == null) { throw "result was null"; }
            
            const wrapped = ServerResponse.wrap(result);
            let k: keyof typeof this.cors_headers;
            for (k in this.cors_headers) {
                if (this.cors_headers[k]) { wrapped.headers.set(k, this.cors_headers[k] ?? '')}
            }
            return wrapped.toWeb();
        }
        catch (error) {
            console.error(error);
            return this.respond_error(500, "Unknown Error");
        }
    }

    // deno-lint-ignore no-explicit-any
    withSpec(jsSpec:any, swaggerPath='swagger.json') {
        this.router.get(swaggerPath, (req:ServerRequest) => {
            const {host, path} = this.getPublicUrl(req);

            const withPath = {...jsSpec};
            withPath.host = host;
            withPath.basePath = path.replace('/'+swaggerPath, '');
            return withPath;
        });
        return this;
    }

    getPublicUrl(req:ServerRequest) {
        const forwarded_host = req.headers.get('x-forwarded-host');

        if (forwarded_host) {
            const forwarded_host = req.headers.get('x-forwarded-host');
            const forwarded_path = req.headers.get('x-forwarded-path');
            const forwarded_port = req.headers.get('x-forwarded-port');

            let host = forwarded_host;
            if (forwarded_port) host += `:${forwarded_port}`;
            const path = forwarded_path ? forwarded_path : req.path;
            return {host, path};
        }

        const url = new URL(req.url);
        return {host: url.host, path: url.pathname};
    }

    withCors(allowOrigin?: string | null, allowHeaders?: string | null, allowMethods?: string | null,) {
        if (allowOrigin) {
            this.cors_headers["Access-Control-Allow-Origin"] = allowOrigin;
        }
        if (allowHeaders) {
            this.cors_headers["Access-Control-Allow-Headers"] = allowHeaders;
        }
        if (allowMethods) {
            this.cors_headers["Access-Control-Allow-Methods"] = allowMethods;
        }
        return this;
    }

    // deno-lint-ignore no-explicit-any
    respond_json(code:number, obj:any) {
        return new Response(JSON.stringify(obj),  { headers: { ...this.cors_headers}, status: code, })
    }

    respond_code(code:number) {
        return new Response('',  { headers: { ...this.cors_headers}, status: code, })
    }

    respond_error(code:number, message:string) {
        return new Response(JSON.stringify({ error: message }), {
            headers: { ...this.cors_headers, 'Content-Type': 'application/json' },
            status: code,
        })
    }

    cors_headers: CorsHeaders = {}
}

export const create = (functionName:string) => {
    return new SupaPogo(functionName);
}

export const respond_empty = (status:number):ServerResponse => {
    return new ServerResponse({
        status: status
    });
}

// deno-lint-ignore no-explicit-any
export const respond_ok = (body:any):ServerResponse => {
    return respond_object(200, body);
}

export const respond_error = (status:number, message:string) => {
    console.error(`Error ${status}: ${message}`)
    return respond_object(status, {message});
}

// deno-lint-ignore no-explicit-any
export const respond_object = (status:number, body:any) => {
    return new ServerResponse({
        body: body,
        status: status
    });
}

export interface CorsHeaders {
    "Access-Control-Allow-Origin"?: string;
    "Access-Control-Allow-Headers"?: string;
    "Access-Control-Allow-Methods"?: string;
}