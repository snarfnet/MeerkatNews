import jwt, time, requests, sys

KEY_ID = 'WDXGY9WX55'
ISSUER = '2be0734f-943a-4d61-9dc9-5d9045c46fec'
APP_ID = '6763823577'
BUILD_NUMBER = sys.argv[1]

p8 = open('/tmp/asc_key.p8').read()

def make_token():
    return jwt.encode(
        {'iss': ISSUER, 'iat': int(time.time()), 'exp': int(time.time()) + 1200, 'aud': 'appstoreconnect-v1'},
        p8, algorithm='ES256', headers={'kid': KEY_ID}
    )

def api(method, path, **kwargs):
    r = requests.request(method, f'https://api.appstoreconnect.apple.com/v1{path}',
        headers={'Authorization': f'Bearer {make_token()}', 'Content-Type': 'application/json'}, **kwargs)
    return r.json()

print(f'Waiting for build {BUILD_NUMBER} to be processed...')
build_id = None
for i in range(80):
    r = api('GET', f'/builds?filter[app]={APP_ID}&filter[version]={BUILD_NUMBER}&filter[processingState]=VALID&limit=1')
    if r.get('data'):
        build_id = r['data'][0]['id']
        print(f'Build ready: {build_id}')
        break
    print(f'  Waiting... ({i+1}/40)')
    time.sleep(30)

if not build_id:
    print('ERROR: Build not found after 20 minutes')
    sys.exit(1)

r = api('GET', f'/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION')
if not r.get('data'):
    print('No PREPARE_FOR_SUBMISSION version found - app may already be in review')
    sys.exit(0)
version_id = r['data'][0]['id']
print(f'Version ID: {version_id}')

r = api('PATCH', f'/appStoreVersions/{version_id}/relationships/build',
    json={'data': {'type': 'builds', 'id': build_id}})
print('Build assigned')

r = api('POST', '/appStoreVersionSubmissions',
    json={'data': {'type': 'appStoreVersionSubmissions', 'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': version_id}}}}})
if r.get('data'):
    print('Submitted for review!')
else:
    print('Submit result:', r)
