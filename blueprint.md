# App Blueprint: Eerste Stapjes

## Overzicht

Eerste Stapjes is een mobiele applicatie gebouwd met Flutter, ontworpen om de groei en ontwikkeling van kinderen vast te leggen en te bewaren. Gebruikers kunnen inloggen met hun Google-account en vervolgens individuele profielen aanmaken voor hun kinderen. Voor elk profiel kan de gebruiker een visuele tijdlijn creëren door dagelijks een foto toe te voegen. De app maakt intensief gebruik van Firebase voor backend-services, waaronder authenticatie, dataopslag en bestandsopslag.

---

## Geïmplementeerde Features, Stijl & Design

### Architectuur & Technologie

-   **Framework:** Flutter
-   **Backend:** Firebase (Authentication, Firestore, Storage)
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

### Notificaties & Achtergrondtaken
-   **Dagelijkse Herinnering:** De app voert dagelijks een achtergrondtaak uit met `workmanager`.
-   **Logica:** Deze taak controleert of de ingelogde gebruiker die dag al een foto heeft geüpload.
-   **Push Notificatie:** Als er geen foto is gevonden, wordt er een lokale notificatie verstuurd met de herinnering: "Vergeet je foto niet!".

### User Interface (UI) & User Experience (UX)

-   **Design Stijl:** Material Design 3.
-   **Thema:** Ondersteuning voor lichte en donkere modus.
-   **Layout:** Diverse layout-problemen zijn opgelost voor een strakkere en professionelere uitstraling.

---

## Huidig Plan: Dagelijkse Notificaties & APK Build

-   **Status:** Voltooid.
-   **Doel:** Een achtergrondtaak implementeren die gebruikers dagelijks herinnert om een foto te uploaden en een productie-APK bouwen.

### Implementatiestappen

1.  **Dependencies Toevoegen:** `workmanager` en `flutter_local_notifications` toegevoegd aan `pubspec.yaml`.
2.  **Notification Service:** Een `NotificationService` opgezet om de creatie en weergave van lokale notificaties te beheren.
3.  **Workmanager Implementatie:**
    -   Een `callbackDispatcher` top-level functie gedefinieerd die op de achtergrond wordt uitgevoerd.
    -   Een periodieke taak (`dailyPhotoReminder`) geregistreerd die elke 24 uur wordt geactiveerd.
    -   De taak controleert in Firestore of er voor de huidige gebruiker al een foto bestaat voor de huidige dag.
    -   Indien nee, wordt de `NotificationService` aangeroepen om de herinnering te tonen.
4.  **Native Android Configuratie:**
    -   De `minSdkVersion` in `android/app/build.gradle.kts` verhoogd naar 23, een vereiste voor `workmanager`.
    -   Kortstondig een custom `Application.kt` class toegevoegd. Dit veroorzaakte build-fouten door verouderde plugin-registratie methoden.
5.  **Foutoplossing & Herstel:**
    -   De build-fout geanalyseerd en de oorzaak (verouderde native code) geïdentificeerd.
    -   De custom `Application.kt` en de bijbehorende referentie in `AndroidManifest.xml` verwijderd, terugvallend op de moderne, automatische plugin-registratie van Flutter.

### Resultaat

-   **APK Gebouwd:** De `flutter build apk` opdracht is succesvol uitgevoerd.
-   **Installatiebestand:** Het productie-APK bestand is beschikbaar op `build/app/outputs/flutter-apk/app-release.apk`.
-   **Volgende Stap:** De app is technisch gereed voor distributie via de Google Play Store. Het uploaden en beheren van de release gebeurt via de Google Play Console.
