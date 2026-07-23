# tech.case.sg

The knowledge layer. One store for what we know, shared across every Claude
instance, account and platform - then handed to projects so they run standalone.

**This repo is the source of truth for the schema.** The database is built by
applying the files in `supabase/migrations` in order. Never apply DDL by hand.

Supabase project: `Claude Tech Portal` (ref `tuhktknixeeacvdjhcfh`).

## Layout

    supabase/migrations/001_knowledge_layer.sql   identity, fact, write_attempt, lease
        supabase/migrations/002_fact_write.sql        the enforcement functions
            supabase/migrations/003_seed_method.sql       starting rules, seeded as proposals
                panel/                                        the Netlify site
                    netlify.toml                                  publishes panel/

                    ## The rules the database enforces

                    1. A write must name the row it supersedes. Not the current row, refused.
                    2. Observation time never goes backwards. An old setup re-run is refused.
                    3. `origin='claude'` lands `proposed`. It is not truth until promoted.

                    Rejections are **recorded, not raised** - an exception would roll back the
                    audit row with it, and a stale write would fail invisibly.

                    ## Separation

                    This system sits above the other projects and outlives them. It shares no
                    Supabase project, no Netlify site and no schema with any of them.

                    The browser profile matters as much as the rest: it is the blast radius. A
                    profile signed in only to this system's accounts cannot accidentally act on
                    another project, and it becomes the first entry in the registry it is used to
                    build.

                    ## Seed and graduate

                    A project draws from this store at the start, then graduates to a pinned
                    standalone copy. Its main functions must run with **no Claude and no central
                    dependency**. Tracking resumes when a Claude session links back in.

                    The pin carries a version, so a project running old method is visible rather
                    than quietly drifting.

                    ## What is not here yet

                    - The shared auth user for the panel
                    - Machine registration - needs a shell on each Mac (IOPlatformUUID, serial)
                    - Browser targets - needs chrome://version read per profile to capture the
                      profile path, which is the anchor. deviceId is a session handle and churns.
                      
