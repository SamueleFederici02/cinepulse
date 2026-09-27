# Privacy Policy for CinePulse

**Last updated:** September 2026

**CinePulse** ("we", "our", or "the app") is committed to protecting your privacy. This Privacy Policy explains our practices regarding user information.

---

### 1. Summary (Zero Tracking & 100% Local On-Device Processing)
- **We do NOT collect, sell, or transmit any personal data to our own servers.**
- **No Account Registration required**: CinePulse does not require you to create an account, password, or provide an email address.
- **100% Local Storage**: All your film history, ratings, watchlists, and computed taste profiles are stored exclusively on your device using local storage (`Hive` / local app sandbox).

---

### 2. Information Handled by the App

#### A. Letterboxd Data Import
- When you import your public Letterboxd username or Letterboxd ZIP/CSV export archive (`ratings.csv`, `watched.csv`, `watchlist.csv`), the file is processed **entirely on your device**.
- None of your personal viewing history is ever uploaded to any third-party server or backend.

#### B. Public Movie Metadata and Streaming Availability
- To provide movie descriptions, high-resolution backdrops, genres, streaming availability, and ratings, CinePulse communicates with:
  - **The Movie Database (TMDb)** API: To fetch movie titles, posters, release dates, and streaming provider lists. (TMDb Privacy Policy: https://www.themoviedb.org/privacy-policy)
  - **Open Movie Database (OMDb)**: To display aggregate critical ratings (such as Rotten Tomatoes, Metacritic, and IMDb).
- These network requests contain only standard public movie queries (e.g., search keywords, movie IDs) and do not contain any personally identifiable information.

#### C. Third-Party Links & Trailers
- When you tap on a trailer, CinePulse opens the official YouTube trailer using your device's default browser or YouTube app. We do not control and are not responsible for the privacy practices of third-party platforms.

---

### 3. Device Permissions
- **INTERNET (`android.permission.INTERNET`)**: Required strictly to fetch public movie posters, descriptions, and streaming availability from TMDb.
- **ACCESS_NETWORK_STATE (`android.permission.ACCESS_NETWORK_STATE`)**: Used to detect whether your device is connected to the internet before performing requests.
- **No Sensitive Permissions**: CinePulse does **not** request access to your Location, Contacts, Camera, Microphone, or Phone state.

---

### 4. Children’s Privacy
CinePulse does not knowingly collect or solicit any personal information from children under the age of 13.

---

### 5. Legal Disclaimers & Attribution
- This product uses the TMDB API but is not endorsed or certified by TMDB.
- Streaming availability data is aggregated via JustWatch / TMDb.
- CinePulse is an independent, open-source companion application and is not affiliated, associated, authorized, endorsed by, or in any way officially connected with Letterboxd Limited or any of its subsidiaries or affiliates.

---

### 6. Contact Us
If you have any questions or feedback regarding this Privacy Policy, please open an issue on the GitHub repository:  
https://github.com/SamueleFederici02/cinepulse
