# App Blueprint: Eerste Stapjes

## Overzicht

Eerste Stapjes is een mobiele applicatie gebouwd met Flutter, ontworpen om de groei en ontwikkeling van kinderen vast te leggen en te bewaren. Gebruikers kunnen inloggen met hun Google-account en vervolgens individuele profielen aanmaken voor hun kinderen. Voor elk profiel kan de gebruiker een visuele tijdlijn creëren door dagelijks een foto toe te voegen. De app maakt intensief gebruik van Firebase voor backend-services, waaronder authenticatie, dataopslag en bestandsopslag.

---

## Geïmplementeerde Features, Stijl & Design

### Architectuur & Technologie

-   **Framework:** Flutter
-   **Backend:** Firebase (Authentication, Firestore, Storage, Cloud Functions)
-   **State Management:** Provider
-   **Authenticatie:** Google Sign-In.
-   **Opslag:** Firebase Storage voor media, Firestore voor metadata.

### Kernfunctionaliteit

-   **Gebruikersprofielen:** Aanmaken, bijwerken en verwijderen van kinderprofielen.
-   **Fotogalerij:** Grid-weergave van alle geüploade foto's voor een profiel.
-   **Dagelijkse Foto Upload:** Gebruikers kunnen een foto en beschrijving toevoegen als dagelijkse 'entry'. De app zorgt ervoor dat er maar één entry per dag mogelijk is.
-   **Post Beheer:** Gebruikers kunnen hun eigen posts verwijderen.

### Sociale Interactie:
    - **Likes:** Zowel eigenaren als volgers kunnen posts 'liken'.
    - **Reacties:** Gebruikers kunnen reageren op posts en hun eigen reacties bewerken of verwijderen.
    - **Favorieten:** Gebruikers kunnen posts markeren als persoonlijk favoriet.
    - **Volgerslijst:** Eigenaren kunnen zien wie hun profielen volgt.

### Notificaties
- **Real-time Notificaties:** Gebruikers ontvangen pushnotificaties voor belangrijke gebeurtenissen zoals nieuwe volgers, likes en reacties.
- **Specifieke Notificaties:**
    - Nieuwe volger: De eigenaar van een profiel ontvangt een notificatie.
    - Nieuwe like: De eigenaar van de post ontvangt een notificatie.
    - Nieuwe reactie: De eigenaar van de post ontvangt een notificatie.

### Probleemoplossing & Herstel

-   **Status:** Voltooid.
-   **Probleem:** Na een eerdere wijziging was het uploaden van foto's gebroken. Een poging dit te herstellen, zorgde er vervolgens voor dat de notificaties voor likes en reacties niet meer werkten, omdat de app-code en de Cloud Functies niet meer op één lijn zaten qua datastructuur (`profiles` vs `users` collectie).
-   **Oplossing:**
    1.  **Herstel App-code:** De Flutter-applicatiecode is volledig teruggezet naar een vorige, stabiele staat, waardoor het uploadprobleem direct werd verholpen.
    2.  **Correctie Cloud Functies:** In plaats van de app opnieuw aan te passen, zijn de Cloud Functies in `functions/index.js` volledig herschreven.
        *   Alle database-triggers luisteren nu naar de correcte `profiles` collectie.
        *   De logica voor het afhandelen van nieuwe likes, reacties en het versturen van notificaties naar volgers is volledig afgestemd op de datastructuur die de app gebruikt.

- **Status:** Voltooid.
- **Probleem:** De release-versie van de Android-app crashte bij het inloggen met Google, omdat de SHA-1 en SHA-256-fingerprints van de release-keystore niet waren toegevoegd aan het Firebase-project. Dit resulteerde in een `PlatformException` en een mislukte authenticatie.
- **Oplossing:**
    1. **Genereren van een Nieuwe Keystore:** Er is een nieuwe, correcte `upload-keystore.jks` aangemaakt.
    2. **Veilige Opslag van Credentials:** De wachtwoorden en aliassen zijn opgeslagen in `android/key.properties`, dat is toegevoegd aan `.gitignore` om te voorkomen dat gevoelige informatie in de repository terechtkomt.
    3. **Configureren van `build.gradle.kts`:** Het build-script is aangepast om de nieuwe keystore te gebruiken voor het ondertekenen van release-builds.
    4. **Toevoegen van SHA-Fingerprints aan Firebase:** De SHA-1- en SHA-256-fingerprints van de nieuwe keystore zijn handmatig uitgelezen en toegevoegd aan de Android-app-configuratie in de Firebase-console.
    5. **Opschonen en Herbouwen:** `gradlew clean` en `flutter clean` zijn uitgevoerd, gevolgd door een nieuwe `flutter build apk --release` om een correct ondertekende APK te genereren.
    6. **Commit & Push:** Alle wijzigingen zijn vastgelegd en gepusht naar de GitHub-repository.
---
## Huidige Taak: Profielverificatie voor Volgen

### Doel
Voorkomen dat gebruikers een ander profiel kunnen volgen als hun eigen account geen naam en profielfoto heeft. Dit zorgt ervoor dat profieleigenaren altijd kunnen zien wie hen volgt.

### Plan van Aanpak
1.  **Identificeer de Volg-logica:** Lokaliseer de code die wordt uitgevoerd wanneer een gebruiker op de "Volgen"-knop drukt.
2.  **Haal Gebruikersdata op:** Voordat de volg-actie wordt uitgevoerd, haal de gegevens op van de ingelogde gebruiker uit de `users` collectie in Firestore.
3.  **Implementeer de Controle:**
    *   Controleer of de velden `displayName` en `photoURL` van de gebruiker niet leeg of `null` zijn.
4.  **Geef Feedback aan de Gebruiker:**
    *   **Indien incompleet:** Toon een dialoogvenster of een `SnackBar` met de melding dat ze eerst hun eigen profiel moeten aanvullen (naam en foto) voordat ze anderen kunnen volgen. Bied eventueel een directe link naar de profielbewerkingspagina.
    *   **Indien compleet:** Sta de volg-actie toe en ga verder met de bestaande logica.
5.  **Testen:** Verifieer beide scenario's grondig om zeker te weten dat de controle correct werkt.
