# ============================================================
# Add 50 dummy contacts to Android emulator via ADB
# Usage: powershell -ExecutionPolicy Bypass -File add_contacts.ps1
# ============================================================

$adb = "C:\Users\lijo.daniel\AppData\Local\Android\Sdk\platform-tools\adb.exe"

$contacts = @(
    # 1-10
    @{ First="Alice";     Last="Johnson";    Phone="+14155551001"; Email="alice.johnson@gmail.com";          Company="Google" },
    @{ First="Bob";       Last="Smith";      Phone="+14155551002"; Email="bob.smith@outlook.com";            Company="Microsoft" },
    @{ First="Charlie";   Last="Brown";      Phone="+14155551003"; Email="charlie.brown@yahoo.com";          Company="Apple" },
    @{ First="Diana";     Last="Prince";     Phone="+14155551004"; Email="diana.prince@amazon.com";          Company="Amazon" },
    @{ First="Edward";    Last="Norton";     Phone="+14155551005"; Email="edward.norton@netflix.com";         Company="Netflix" },
    @{ First="Fiona";     Last="Green";      Phone="+14155551006"; Email="fiona.green@spotify.com";          Company="Spotify" },
    @{ First="George";    Last="Harrison";   Phone="+14155551007"; Email="george.h@tesla.com";               Company="Tesla" },
    @{ First="Hannah";    Last="Wilson";     Phone="+14155551008"; Email="hannah.w@adobe.com";               Company="Adobe" },
    @{ First="Isaac";     Last="Newton";     Phone="+14155551009"; Email="isaac.n@spacex.com";               Company="SpaceX" },
    @{ First="Julia";     Last="Roberts";    Phone="+14155551010"; Email="julia.r@meta.com";                 Company="Meta" },
    # 11-20
    @{ First="Kevin";     Last="Hart";       Phone="+14155551011"; Email="kevin.hart@uber.com";              Company="Uber" },
    @{ First="Laura";     Last="Palmer";     Phone="+14155551012"; Email="laura.p@airbnb.com";               Company="Airbnb" },
    @{ First="Michael";   Last="Scott";      Phone="+14155551013"; Email="michael.scott@dundermifflin.com";  Company="Dunder Mifflin" },
    @{ First="Nancy";     Last="Drew";       Phone="+14155551014"; Email="nancy.drew@intel.com";             Company="Intel" },
    @{ First="Oliver";    Last="Twist";      Phone="+14155551015"; Email="oliver.t@nvidia.com";              Company="NVIDIA" },
    @{ First="Patricia";  Last="Clark";      Phone="+14155551016"; Email="patricia.c@oracle.com";            Company="Oracle" },
    @{ First="Quincy";    Last="Adams";      Phone="+14155551017"; Email="quincy.a@ibm.com";                 Company="IBM" },
    @{ First="Rachel";    Last="Green";      Phone="+14155551018"; Email="rachel.g@salesforce.com";          Company="Salesforce" },
    @{ First="Samuel";    Last="Jackson";    Phone="+14155551019"; Email="samuel.j@twitter.com";             Company="Twitter" },
    @{ First="Tina";      Last="Turner";     Phone="+14155551020"; Email="tina.t@samsung.com";               Company="Samsung" },
    # 21-30
    @{ First="Uma";       Last="Thurman";    Phone="+14155551021"; Email="uma.t@sony.com";                   Company="Sony" },
    @{ First="Victor";    Last="Hugo";       Phone="+14155551022"; Email="victor.h@dell.com";                Company="Dell" },
    @{ First="Wendy";     Last="Williams";   Phone="+14155551023"; Email="wendy.w@hp.com";                   Company="HP" },
    @{ First="Xavier";    Last="Patel";      Phone="+14155551024"; Email="xavier.p@cisco.com";               Company="Cisco" },
    @{ First="Yolanda";   Last="Chen";       Phone="+14155551025"; Email="yolanda.c@zoom.com";               Company="Zoom" },
    @{ First="Zachary";   Last="Taylor";     Phone="+14155551026"; Email="zachary.t@slack.com";              Company="Slack" },
    @{ First="Amelia";    Last="Watson";     Phone="+14155551027"; Email="amelia.w@stripe.com";              Company="Stripe" },
    @{ First="Brandon";   Last="Lee";        Phone="+14155551028"; Email="brandon.l@shopify.com";            Company="Shopify" },
    @{ First="Catherine"; Last="Bell";       Phone="+14155551029"; Email="catherine.b@lyft.com";             Company="Lyft" },
    @{ First="David";     Last="Kim";        Phone="+14155551030"; Email="david.k@snap.com";                 Company="Snap" },
    # 31-40
    @{ First="Elena";     Last="Rodriguez";  Phone="+14155551031"; Email="elena.r@pinterest.com";            Company="Pinterest" },
    @{ First="Frank";     Last="Miller";     Phone="+14155551032"; Email="frank.m@dropbox.com";              Company="Dropbox" },
    @{ First="Grace";     Last="Hopper";     Phone="+14155551033"; Email="grace.h@linkedin.com";             Company="LinkedIn" },
    @{ First="Henry";     Last="Ford";       Phone="+14155551034"; Email="henry.f@paypal.com";               Company="PayPal" },
    @{ First="Iris";      Last="Chang";      Phone="+14155551035"; Email="iris.c@square.com";                Company="Square" },
    @{ First="James";     Last="Murphy";     Phone="+14155551036"; Email="james.m@twitch.com";               Company="Twitch" },
    @{ First="Karen";     Last="White";      Phone="+14155551037"; Email="karen.w@reddit.com";               Company="Reddit" },
    @{ First="Liam";      Last="OBrien";     Phone="+14155551038"; Email="liam.o@github.com";                Company="GitHub" },
    @{ First="Maria";     Last="Garcia";     Phone="+14155551039"; Email="maria.g@atlassian.com";            Company="Atlassian" },
    @{ First="Nathan";    Last="Brooks";     Phone="+14155551040"; Email="nathan.b@notion.com";              Company="Notion" },
    # 41-50
    @{ First="Olivia";    Last="Martinez";   Phone="+14155551041"; Email="olivia.m@figma.com";               Company="Figma" },
    @{ First="Peter";     Last="Parker";     Phone="+14155551042"; Email="peter.p@marvel.com";               Company="Marvel" },
    @{ First="Quinn";     Last="Hughes";     Phone="+14155551043"; Email="quinn.h@vercel.com";               Company="Vercel" },
    @{ First="Rosa";      Last="Diaz";       Phone="+14155551044"; Email="rosa.d@mongodb.com";               Company="MongoDB" },
    @{ First="Steve";     Last="Rogers";     Phone="+14155551045"; Email="steve.r@cloudflare.com";           Company="Cloudflare" },
    @{ First="Tara";      Last="Singh";      Phone="+14155551046"; Email="tara.s@datadog.com";               Company="Datadog" },
    @{ First="Ursula";    Last="Grant";      Phone="+14155551047"; Email="ursula.g@elastic.com";             Company="Elastic" },
    @{ First="Vincent";   Last="Zhao";       Phone="+14155551048"; Email="vincent.z@twilio.com";             Company="Twilio" },
    @{ First="Wanda";     Last="Maximoff";   Phone="+14155551049"; Email="wanda.m@docker.com";               Company="Docker" },
    @{ First="Xander";    Last="Cole";       Phone="+14155551050"; Email="xander.c@hashicorp.com";           Company="HashiCorp" }
)

Write-Host "Adding $($contacts.Count) contacts to emulator...`n"

$id = 1
foreach ($c in $contacts) {
    Write-Host "[$id/$($contacts.Count)] Adding $($c.First) $($c.Last)..."

    # Insert raw contact
    & $adb shell "content insert --uri content://com.android.contacts/raw_contacts --bind account_type:s: --bind account_name:s:"

    # Insert display name
    & $adb shell "content insert --uri content://com.android.contacts/data --bind raw_contact_id:i:$id --bind mimetype:s:vnd.android.cursor.item/name --bind data2:s:$($c.First) --bind data3:s:$($c.Last)"

    # Insert phone number
    & $adb shell "content insert --uri content://com.android.contacts/data --bind raw_contact_id:i:$id --bind mimetype:s:vnd.android.cursor.item/phone_v2 --bind data1:s:$($c.Phone) --bind data2:i:2"

    # Insert email
    & $adb shell "content insert --uri content://com.android.contacts/data --bind raw_contact_id:i:$id --bind mimetype:s:vnd.android.cursor.item/email_v2 --bind data1:s:$($c.Email) --bind data2:i:1"

    # Insert company
    & $adb shell "content insert --uri content://com.android.contacts/data --bind raw_contact_id:i:$id --bind mimetype:s:vnd.android.cursor.item/organization --bind data1:s:$($c.Company)"

    $id++
}

Write-Host "`nDone! $($contacts.Count) contacts added to emulator."
Write-Host "Verify with: adb shell `"content query --uri content://com.android.contacts/contacts --projection display_name`""
