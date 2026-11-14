# Prime Football 27 · Cloud saves & Companion app

1. Create a free project at https://supabase.com (any name/region, set a database password).
2. In the project: **SQL Editor → New query**, paste everything in `supabase_setup.sql`, press **Run**.
3. **Project Settings → API**: copy the **Project URL** and the **anon public** key.
4. Either send both to Claude to bake into the builds, or paste them in the game: Settings → ☁ Cloud Account → Server setup.
5. In the game: ☁ Cloud Account → choose a username + 4–6 digit PIN → **Create account** (uploads that save slot).
6. On your phone open https://qrw6741.github.io/TONIFC/companion/ and sign in with the same username + PIN.

The anon key is safe to ship: the table is locked by row-level security and only the `pf_*` functions can touch it, and they all check the PIN (stored bcrypt-hashed).
