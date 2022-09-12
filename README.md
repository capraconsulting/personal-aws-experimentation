# personal-aws-experimentation
Dette repoet legger frem noen guider og eksempelkode på hvordan man enkelt kan komme i gang med infrastruktur-som-kode el. «Infrastructure-as-Code» (IaC) i sin private AWS-konto. Du kan enkelt lage en kopi av dette repoet ved å trykke på **[Use this template](https://github.com/capraconsulting/personal-aws-experimentation/generate)** øverst på siden, endre **Owner** til din personlige GitHub-bruker, og huke av for at repoet skal være **Private**

Det finnes flere verktøy og språk for IaC -- AWS Cloud Development Kit (CDK), AWS CloudFormation, Terraform, Pulumi, osv. Sluttresultatet av å følge guidene under er et personlig GitHub-repository hvor man kan bruke Terraform for å definere AWS-infrastruktur. På veien vil man også ta i bruk AWS CloudFormation for å «bootstrappe» AWS-kontoen med et par nyttige skyressurser for tilgangsstyring og for å kunne Terraform på et robust og sikkert vis. Man får i tillegg toucha innom både manuelle operasjoner via AWS-konsollen (el. såkalt «ClickOps» 🖱), AWS CLI og nyttige CLI-verktøy for å arbeide mot AWS.

(_ℹ️ Guidene under er i utgangspunktet tiltenkt bruk i en nylig opprettet AWS-konto hvor man kun har tilgang via AWS-«rotbruker», så hvis du allerede har satt opp noen form for alternativ tilgangsstyring som følger god praksis i AWS-kontoen din, så kan du i stedet lese gjennom og bruke informasjon i dette repoet som en referanse og ta i bruk det som virker nyttig for deg._)

<details>
<summary><b>Litt om Terraform</b></summary>

Terraform er et populært open-source verktøy som brukes for å enkelt opprette, endre og slette infrastruktur definert som IaC. Man definerer ønsket infrastruktur i en eller flere `.tf`-filer, og bruker deretter Terraform til gjøre vår _ønskede_ infrastruktur om til _reell_ infrastruktur. Terraform leser filene våre, og finner ut hvilke ressurser som må opprettes, endres, slettes, osv., og finner ut rekkefølgen alt dette må gjøres i.

For et gitt prosjekt opererer Terraform med en intern state-fil (en `.tfstate`-fil) som den bruker til å lagre alle ressurser den er kjent med for det respektive prosjektet. Terraform bruker denne filen til å ha en oversikt over alle ressurser (og deres attributter), samt avhengighetsgrafen mellom ulike ressurser. Det er ikke veldig gøy å miste denne filen, og man lagrer den derfor typisk på et sentralt sted (f. eks. AWS S3) med støtte for versjonering.

Terraform integrerer seg mot ulike tjenester vha. _providers_. Man kan ta i bruk en provider for å få tilgang til ressurser som man deretter kan bruke i Terraform -- se på det som en modul i Python eller et bibliotek i Java. Det finnes f. eks. en provider som lar oss opprette ressurser i Amazon Web Services (AWS), en annen som lar oss opprette ressurser i Google Cloud Platform (GCP), mens andre tilbyr generell og nyttig funksjonalitet. Terraform er dermed ikke spesielt knyttet til skytjenester selv om det er der det ofte blir brukt -- det finnes providers for veldig mye forskjellig. Ved å bruke providers trenger vi som endebrukere kun å skrive hvilke ressurser vi ønsker å opprette, og så lar vi Terraform og en eller flere providers håndtere de komplekse detaljene behind-the-scenes (f. eks. API-kall mot AWS, GCP osv.).

I tillegg kan man ta i bruk gjenbrukbare moduler, som i bunn og grunn er en samling av ressurser fra en eller flere providers. Disse kan man skrive selv, eller bruke en av de flere tusen som finnes open-source på GitHub. Dette gjør at man enkelt kan opprette kompleks infrastruktur med lite kode!

Et par ting som kan være greie å vite om Terraform:

- Alle `.tf`-filer i en gitt mappe blir slått sammen til én når Terraform leser koden din. Man splitter typisk ut kode i forskjellige filer for å gjøre kodebasen enklere å navigere, men man kan i teorien ha alt i én stor fil hvis man ønsker.
- Rekkefølge på kode har ingenting å si. Terraform bygger opp en graf av infrastrukturen man har definert, og finner automatisk ut hvilken rekkefølge ting må opprettes i. F. eks. hvis ressurs A refererer til ressurs B, så skjønner Terraform at A må opprettes før B -- man trenger ikke å skrive dette eksplisitt.
- Det er bygget et stort og aktivt open-source miljø rundt Terraform. Det finnes flere hundre providers, og flere tusen moduler!
- Det benytter seg av et språk, HashiCorp Configuration Language (HCL), som er en utvidelse av JSON. Dette språket lar oss definere infrastruktur på et enklere og mer leselig vis enn f. eks. JSON og YAML.

</details>

## Installasjonskrav
- En AWS-konto.
- [aws-cli](https://aws.amazon.com/cli/) (AWS sitt offisielle kommandolinjeverktøy for å ta i bruk deres API).
- [aws-vault](https://github.com/99designs/aws-vault) (et tredjepartsverktøy som hjelper oss å håndtere AWS-nøkler på en sikker måte).
- [asdf](https://github.com/asdf-vm/asdf) (asdf er et plugin-basert CLI-verktøy som gjør det enkelt å installere og bytte mellom ulike versjoner av Terraform, Node, Python, o.l.).
- Authy, Google Authenticator e.l. installert på telefonen din (nødvendig for å kunne sette opp tofaktorautentisering).

## 1. Konfigurere tilgangsstyring i AWS
I hver AWS-konto har man en _rotbruker_ som har full styring over hele AWS-kontoen. Som en god praksis bør man minimere bruk av rotbrukeren da man sjeldent trenger denne type tilgang, og i stedet sette opp en dedikert AWS IAM-bruker som har de rettighetene man trenger. Da kan man enklere operere mer iht. det som kalles «[principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege)».

Rotbrukeren kan gjøre alt i en AWS-konto, og gitt disse brede rettighetene er det vanlig (og anbefalt) å bruke dedikerte IAM-brukere og/eller IAM-roller i det daglige. Man bruker typisk rotbrukeren for å gjøre kontoendringer -- slette kontoen, oppdatere fakturering, osv. -- med andre ord operasjoner man sjeldent trenger å gjøre.

Vi skal nå sette opp tofaktorautentisering på AWS-rotbruker, samt opprette en IAM-bruker som lar oss gjøre endringer på AWS-konto vha. IaC. Man trenger AWS-nøkler (el. _credentials_) med veldige brede tilganger for å ta i bruk IaC da man i teorien skal ha mulighet til å kunne opprette, endre og slette alt av ressurser. Man kan etterhvert opprette egne IAM-brukere og/eller IAM-roller som er mer begrenset hvis man ønsker å nekte adgang til spesifikke deler av AWS. Men i starten kan det være greit å bruke en IAM-_policy_ laget av AWS som gir administratortilganger.

### 1a. Konfigurere AWS-rotbruker
1. Logg inn i [AWS-konsollen](https://console.aws.amazon.com/console/home) med epost og passord for AWS-rotbrukeren din.
1. Aktiver tofaktorautentisering for AWS-rotbruker via følgende lenke: https://console.aws.amazon.com/iam/home#/security_credentials > *Multi-factor authentication* > *Activate MFA* > *Virtual MFA Device* > *Continue* > *Show QR code*
1. Skann QR-koden i Authy, Google Authenticator e.l., fyll inn to tidsbaserte som dukker opp etter hverandre i applikasjonen du bruker for tofaktorautentisering og klikk deretter på *Assign MFA*.
1. Gjør kostnadsdetaljer tilgjengelig for IAM-brukere og IAM-roller ved å besøke https://us-east-1.console.aws.amazon.com/billing/home?region=us-east-1&skipRegion=true#/account, deretter klikke på *Edit* ved siden av "IAM User and Role Access to Billing Information", og huke av for _Activate IAM Access_ ✔ > *Update*.

### 1b. Sette opp IAM-bruker
Filen [cloudformation/cfn-developer-access.yml](cloudformation/cfn-developer-access.yml) er en CloudFormation-mal som oppretter ressurser som gir deg tilgang til AWS uten å måtte bruke AWS-rotbruker. Vi skal nå sette opp en CloudFormation-«stack» som bruker denne malen.
1. Besøk https://eu-west-1.console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/create/template > *Upload a template file* > *Choose file* > `cloudformation/cfn-developer-access.yml` > *Next*
1. Gi stacken navnet "capra-developer-access"
1. Under _Parameters_, sett _UserName_ til "fornavn.etternavn" (bytt ut med ditt faktiske navn 😄) > Next > Huk av for "I acknowledge that AWS CloudFormation might create IAM resources with custom names" ✔ > *Create stack*.
1. Vent til opprettelse av stack er ferdig ...
1. Klikk deg inn på [IAM](https://console.aws.amazon.com/iam/home?#/users) og klikk på brukeren som nylig ble opprettet.
1. Aktiver tofaktorautentisering for IAM-brukeren ved å klikke på *Security credentials* > *Multi-factor authentication* > *Activate MFA* > *Virtual MFA Device* > *Continue* > *Show QR code*
1. Skann QR-koden i Authy, Google Authenticator e.l., fyll inn to tidsbaserte som dukker opp etter hverandre i applikasjonen du bruker for tofaktorautentisering og klikk deretter på *Assign MFA*.
1. Under "Access keys", klikk på *Create access key*.
1. En *Access key ID* og *Secret access key* skal nå ha blitt opprettet for den nye brukeren. Hold nettsiden åpen mens vi konfigurerer `aws-vault` til å lagre disse nøklene.
1. Åpne opp en terminal og kjør `$ aws-vault add capra-personal` og fyll inn nøklene fra forrige steg.
1. Legg til følgende snutt i `~/.aws/config`, og bytt ut `<AWS-KONTO-ID>` og `<AWS-IAM-BRUKER>` med dine verdier. (Opprett mappe og fil hvis i hjemmemappen din hvis disse ikke allerede finnes):
   ```ini
   [profile capra-personal]
   region=eu-west-1
   mfa_serial=arn:aws:iam::<AWS-KONTO-ID>:mfa/<AWS-IAM-BRUKER>

   [profile capra-personal-admin]
   region=eu-west-1
   mfa_serial=arn:aws:iam::<AWS-KONTO-ID>:mfa/<AWS-IAM-BRUKER>
   role_arn=arn:aws:iam::<AWS-KONTO-ID>:role/capra-admin
   source_profile=capra-personal

   [profile capra-personal-developer]
   region=eu-west-1
   mfa_serial=arn:aws:iam::<AWS-KONTO-ID>:mfa/<AWS-IAM-BRUKER>
   role_arn=arn:aws:iam::<AWS-KONTO-ID>:role/capra-developer
   source_profile=capra-personal
   ```
1. Kjør `$ aws-vault exec capra-personal-admin -- aws sts get-caller-identity` og verifiserer at `Arn`-feltet i output samsvarer med ID på AWS-kontoen din og navnet på IAM-rollen som tidligere ble opprettet.

## 2. Ta i bruk «Infrastructure as Code» (IaC) i AWS-kontoen
1. Last ned repoet lokalt, åpne et shell og gå inn i rotmappen av repoet.
1. Kjør `$ asdf install` for å installere riktig Terraform-versjon.
1. Kjør `$ aws-vault exec capra-personal-admin` for å konfigurere nåværende shell til å ta i bruk nøklene du opprettet i sted.
1. Kjør kommandoen under for å opprette nødvendige ressurser for Terraform vha. CloudFormation. En CloudFormation-stack vil opprettes som inneholder S3-bøtte og DynamoDB-tabell som Terraform bruker for hhv. lagring av state og låsing av miljø (for å sørge for at det kun er én prosess eller bruker som endrer på statefilen samtidig):
   ```sh
   aws cloudformation create-stack \
     --stack-name "capra-tf-bootstrap" \
     --template-body file://cloudformation/cfn-tf-bootstrap.yml \
     && aws cloudformation wait \
       stack-create-complete \
       --stack-name "capra-tf-bootstrap" \
   ```
1. Følg guiden i [terraform](terraform/).

Du har nå satt opp en kryptert S3-bøtte og konfigurert Terraform til å bruke denne bøtta til å lagre statefil. Du kan nå utvide [main.tf](terraform/main.tf) med providers, ressurser og moduler du ønsker å ta i bruk.

Noen nyttige Terraform-kommandoer å notere seg bak øret er:

- `terraform init`: Opprette et terraform prosjekt i mappen du befinner deg i.
- `terraform plan`: Generere og se en plan for hvilke endringer Terraform planlegger å gjøre, uten å faktisk iverksette endringene.
- `terraform apply`: Iverksette endringene som Terraform har kommet frem til basert på infrastruktur-koden din.
- `terraform validate`: Sjekker om syntaks er riktig og om konfigurasjonen du har satt opp er gyldig (_NB: Denne er "innebygget" i `plan` og `apply` kommandoene, så i de tilfellene trenger man ikke å bruke den. Men den kan være nyttig hvis man ønsker å kun validere_)
- :exclamation: `terraform destroy`: Slett alle ressurser som finnes i statefil i nåværende prosjekt. Forsiktig med denne.

## Roadmap
- [X] ~~Legge til oppsett og guide for bootstrapping av Terraform i AWS~~
- [ ] Legge til ressurser for å lære mer om IaC
- [ ] Legge til eksempler på nyttig IaC (kostnadsalarmer o.l.)
- [ ] Legge til seksjon om gode praksiser (håndtering av nøkler, CI/CD, osv.)
