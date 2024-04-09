# Running

Ensure you've run `npm i` on the `[REPO]/supabase` directory

All other commands will be run in `[REPO]/supabase/supabase`

Run `npx supabase start`

To STOP, run `npx supabase stop` but you can stop without nuking your DB by running `supabase stop --backup`

# DB

## Create a migration

`npx supabase migration new MIGRATIONNAME` then edit the generated file

## Run Migrations

`npx supabase db reset`

## Access the postgres db without installing a client:

* In docker gui, open terminal for the container `supabase_db_supabase`
* Run this cmd: `psql -U postgres` 
* Handy commands: `\d` shows tables. `\d tablename` shows the definition of the table
* Remember all sql commands should be terminated with `;` to run

## Deploying DB

Familiarize with https://supabase.com/docs/guides/getting-started/local-development

`npx supabase link --project-ref <project-id>`

`npx supabase db remote commit`

`npx supabase db push`

# Edge Functions

Create: `npx supabase functions new hello-world`

Run: `npx supabase functions serve --env-file ./supabase/.env.local`

Deploy: `npx supabase functions deploy <function_name>`

Deploy All: `npx supabase functions deploy`

Get a service key to call with: `Settings > API > Project API keys > service_role`

To turn off JWT for a function (so we can secure by apikey instead), add this to `config.toml`:

```
[functions.helloworld]
verify_jwt = false
```