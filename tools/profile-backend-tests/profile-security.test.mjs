import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

// An isolated PostgreSQL fixture, never a hosted Supabase connection. Auth and
// Storage metadata schemas below model only the tables the new migration uses.
const ids = {
  student: '10000000-0000-4000-8000-000000000001',
  vendor: '10000000-0000-4000-8000-000000000002',
  admin: '10000000-0000-4000-8000-000000000003',
  campus1: '20000000-0000-4000-8000-000000000001',
  campus2: '20000000-0000-4000-8000-000000000002',
  inactive: '20000000-0000-4000-8000-000000000003',
};
let db;
before(async () => {
  db = await PGlite.create();
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE SCHEMA auth; CREATE SCHEMA storage;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    CREATE TABLE auth.users(id uuid PRIMARY KEY, email text);
    CREATE TABLE public.universities(id uuid PRIMARY KEY, name text, is_active boolean);
    CREATE TABLE public.profiles(id uuid PRIMARY KEY REFERENCES auth.users, role text,
      full_name text, username text UNIQUE, email text, phone_number text,
      avatar_url text, university_id uuid REFERENCES universities,
      terms_accepted boolean DEFAULT true, updated_at timestamptz DEFAULT now());
    CREATE TABLE public.customers(user_id uuid PRIMARY KEY REFERENCES profiles, university_id uuid REFERENCES universities);
    CREATE TABLE public.vendors(user_id uuid PRIMARY KEY, status text, business_name text);
    CREATE TABLE public.vendor_universities(user_id uuid, university_id uuid);
    CREATE FUNCTION public.is_admin() RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS
      $$ SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='admin') $$;
    CREATE FUNCTION public.handle_updated_at() RETURNS trigger LANGUAGE plpgsql AS
      $$ BEGIN NEW.updated_at := clock_timestamp(); RETURN NEW; END $$;
    CREATE TRIGGER profile_timestamp BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
    CREATE TABLE storage.buckets(id text PRIMARY KEY, public boolean, file_size_limit bigint, allowed_mime_types text[]);
    CREATE TABLE storage.objects(bucket_id text REFERENCES storage.buckets, name text, PRIMARY KEY(bucket_id,name));
    CREATE FUNCTION storage.foldername(name text) RETURNS text[] LANGUAGE sql IMMUTABLE AS
      $$ SELECT (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1] $$;
    INSERT INTO universities VALUES ('${ids.campus1}','UTM',true),('${ids.campus2}','UM',true),('${ids.inactive}','Inactive campus',false);
    INSERT INTO auth.users VALUES ('${ids.student}','student@example.test'),('${ids.vendor}','vendor@example.test'),('${ids.admin}','admin@example.test');
    INSERT INTO profiles(id,role,full_name,username,email,phone_number,university_id) VALUES
      ('${ids.student}','student','Student Demo','student_demo','student@example.test','+60123456789','${ids.campus1}'),
      ('${ids.vendor}','vendor','Vendor Demo','vendor_demo','vendor@example.test','+60123456789',NULL),
      ('${ids.admin}','admin','Admin Demo','admin_demo','admin@example.test','+60123456789',NULL);
    INSERT INTO customers VALUES ('${ids.student}','${ids.campus1}');
    INSERT INTO vendors VALUES ('${ids.vendor}','approved','Unchanged Kitchen');
    INSERT INTO vendor_universities VALUES ('${ids.vendor}','${ids.campus1}');
    INSERT INTO storage.buckets VALUES ('avatars',true,NULL,NULL);
    GRANT USAGE ON SCHEMA auth, storage, public TO anon,authenticated;
    GRANT ALL ON profiles,customers,universities,storage.objects,storage.buckets TO anon,authenticated;
    ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
    ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
    ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "Profiles are viewable by authenticated users" ON profiles FOR SELECT TO authenticated USING(true);
    CREATE POLICY own_profile_update ON profiles FOR UPDATE TO authenticated USING(id=auth.uid()) WITH CHECK(id=auth.uid());
    CREATE POLICY own_customer ON customers FOR ALL TO authenticated USING(user_id=auth.uid()) WITH CHECK(user_id=auth.uid());
    CREATE POLICY "Avatars are publicly accessible" ON storage.objects FOR SELECT USING(bucket_id='avatars');
    CREATE POLICY "Users can upload their own avatar" ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='avatars' AND (storage.foldername(name))[1]=auth.uid()::text);
  `);
  const migration = await readFile(new URL('../../supabase/migrations/20261117000024_edit_own_profile_private_avatars.sql', import.meta.url), 'utf8');
  await db.exec(migration);
});
after(async () => { await db?.close(); });

async function asUser(id, action, role = 'authenticated') {
  return db.transaction(async tx => {
    await tx.exec(`SET LOCAL ROLE ${role}`);
    await tx.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
    return action(tx);
  });
}
async function own(tx, id) {
  return (await tx.query('SELECT *,updated_at::text AS stamp FROM profiles WHERE id=$1', [id])).rows[0];
}
async function update(tx, id, overrides = {}) {
  const row = await own(tx,id);
  const p = { name: row.full_name, username: row.username, phone: row.phone_number,
    campus: row.role === 'student' ? row.university_id : null, avatar: row.avatar_url, stamp: row.stamp, ...overrides };
  return (await tx.query('SELECT public.update_my_personal_profile($1,$2,$3,$4,$5,$6) AS profile',
    [p.name,p.username,p.phone,p.campus,p.avatar,p.stamp])).rows[0].profile;
}

test('student saves permitted fields and campus atomically', async () => {
  const result = await asUser(ids.student, tx => update(tx,ids.student,{name:'Updated Student',username:'updated_student',phone:'+60199887766',campus:ids.campus2}));
  assert.equal(result.full_name,'Updated Student');
  assert.equal(result.username,'updated_student');
  assert.equal(result.role,'student');
  assert.equal(result.email,'student@example.test');
  assert.equal(result.university_id,ids.campus2);
  assert.equal((await db.query('SELECT university_id FROM customers WHERE user_id=$1',[ids.student])).rows[0].university_id,ids.campus2);
});
test('vendor and admin can save personal fields without changing roles or business coverage', async () => {
  for (const role of ['vendor','admin']) {
    const result = await asUser(ids[role],tx=>update(tx,ids[role],{name:`Updated ${role}`}));
    assert.equal(result.role,role);
    assert.equal(result.full_name,`Updated ${role}`);
  }
  assert.deepEqual((await db.query('SELECT status,business_name FROM vendors')).rows,[{status:'approved',business_name:'Unchanged Kitchen'}]);
  assert.equal((await db.query('SELECT university_id FROM vendor_universities')).rows[0].university_id,ids.campus1);
});
test('duplicate usernames roll back all profile and campus changes', async () => {
  await assert.rejects(asUser(ids.student,tx=>update(tx,ids.student,{name:'Must not save',username:'vendor_demo',campus:ids.campus1})),e=>e.code==='23505');
  const result = await db.query('SELECT full_name,university_id FROM profiles WHERE id=$1',[ids.student]);
  assert.deepEqual(result.rows[0],{full_name:'Updated Student',university_id:ids.campus2});
});
test('invalid phone, inactive campuses, and vendor campus changes are rejected', async () => {
  await assert.rejects(asUser(ids.student,tx=>update(tx,ids.student,{phone:'111111111'})),e=>e.code==='22023');
  await assert.rejects(asUser(ids.student,tx=>update(tx,ids.student,{campus:ids.inactive})),e=>e.code==='22023');
  await assert.rejects(asUser(ids.vendor,tx=>update(tx,ids.vendor,{campus:ids.campus2})),e=>e.code==='42501');
});
test('ordinary users cannot read other private profiles or directly change protected columns', async () => {
  const rows = await asUser(ids.student,tx=>tx.query('SELECT id FROM profiles'));
  assert.deepEqual(rows.rows,[{id:ids.student}]);
  for (const sql of ["UPDATE profiles SET role='admin'", "UPDATE profiles SET email='attacker@example.test'", 'TRUNCATE profiles CASCADE']) {
    await assert.rejects(asUser(ids.student,tx=>tx.exec(sql)),e=>e.code==='42501');
  }
  assert.equal((await db.query('SELECT count(*) AS count FROM profiles')).rows[0].count,3);
});
test('anonymous callers cannot invoke the profile RPC', async () => {
  await assert.rejects(asUser(null,tx=>tx.query("SELECT update_my_personal_profile('Anonymous','anonymous_demo','',NULL,NULL,now())"),'anon'),e=>e.code==='42501');
});
test('stale updates cannot overwrite a newer save', async () => {
  await assert.rejects(asUser(ids.student,tx=>update(tx,ids.student,{stamp:'2000-01-01T00:00:00Z'})),e=>e.code==='40001');
});
test('avatar metadata is private and restricted to the owner folder', async () => {
  const ownPath = `${ids.student}/profile/${'a'.repeat(32)}.png`;
  const foreignPath = `${ids.vendor}/profile/${'b'.repeat(32)}.jpg`;
  await asUser(ids.student,tx=>tx.query("INSERT INTO storage.objects VALUES ('avatars',$1)",[ownPath]));
  await asUser(ids.vendor,tx=>tx.query("INSERT INTO storage.objects VALUES ('avatars',$1)",[foreignPath]));
  await assert.rejects(asUser(ids.student,tx=>tx.query("INSERT INTO storage.objects VALUES ('avatars',$1)",[`${ids.admin}/profile/${'c'.repeat(32)}.jpg`])),e=>e.code==='42501');
  const objects = await asUser(ids.student,tx=>tx.query('SELECT name FROM storage.objects'));
  assert.deepEqual(objects.rows,[{name:ownPath}]);
  const anonymous = await asUser(null,tx=>tx.query('SELECT name FROM storage.objects'),'anon');
  assert.deepEqual(anonymous.rows,[]);
  await assert.rejects(asUser(ids.student,tx=>update(tx,ids.student,{avatar:foreignPath})),e=>e.code==='22023');
  await asUser(ids.student,tx=>update(tx,ids.student,{avatar:ownPath}));
  await asUser(ids.student,tx=>update(tx,ids.student,{avatar:null}));
  assert.equal((await db.query("SELECT count(*) AS count FROM storage.objects WHERE name=$1",[ownPath])).rows[0].count,1);
  const bucket = (await db.query("SELECT public,file_size_limit,allowed_mime_types FROM storage.buckets WHERE id='avatars'")).rows[0];
  assert.equal(bucket.public,false);
  assert.equal(Number(bucket.file_size_limit),5242880);
  assert.deepEqual(bucket.allowed_mime_types,['image/jpeg','image/png']);
});
