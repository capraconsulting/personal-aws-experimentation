# Terraform
Denne mappen inneholder Terraform-kode som lagrer state i en kryptert S3-bøtte, samt oppretter et enkelt budsjett i AWS som sender deg en epost hvis du bruker over $50 ila. en måned. Man kan fjerne budsjettet hvis man ønsker, men det er da anbefalt å ta i bruk andre varslingsmekanismer for å unngå at man spinner opp dyre ressurser og glemmer dem ut...

Merk at budsjettet i seg selv bare fører til en varsling, og det er ingen ressurser som blir fjernet eller servere som blir skrudd av som følge av en slik varsling -- det må man evt. selv gjøre.

Du kan initialisere prosjektet ved å gjøre følgende:
1. Bruk riktige AWS credentials på kommandolinjen
2. Åpne [main.tf](main.tf) og erstatt alle placeholders med dine verdier (_placeholders er markert med `# TODO` i koden_)
3. Kjør `terraform init && terraform plan` fra mappen du er i nå
4. Verifiser at endringene ser bra ut
5. Kjør `terraform apply` og svar `yes` for å iverksette endringene.
