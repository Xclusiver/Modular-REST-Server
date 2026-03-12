# Modular REST Server

Wielowątkowy serwer REST API napisany w środowisku Delphi, zaimplementowany w oparciu o zasady **Clean Architecture**. Aplikacja zapewnia wydajny dostęp do danych poprzez framework **HORSE** oraz zaawansowaną warstwę abstrakcji bazy danych z wykorzystaniem wzorca wstrzykiwania zależności i pulowania połączeń w FireDAC.

## Główne cechy

* **Czysta architektura (Clean Architecture):** Pełna separacja interfejsów (warstwa Core) od implementacji (warstwa Infrastructure).
* **Obsługa wielu silników bazodanowych:** Pojedynczy interfejs 'IDatabaseManager' obsługuje obecnie 4 systemy poprzez dynamiczne mapowanie w pliku konfiguracyjnym:
  * **SQLite** (Natywnie)
  * **Firebird** (Natywnie)
  * **MS SQL Server** (Poprzez systemowy ODBC)
  * **Oracle** (Poprzez systemowy ODBC / opcjonalnie Devart ODAC)
* **Wydajność:** Wykorzystanie 'FDManager' do zarządzania pulą połączeń ('Pooled=True'), co zapobiega wyciekom pamięci i zatykaniu bazy przy wielu jednoczesnych zapytaniach HTTP.
* **REST API:** Zbudowane w oparciu o minimalistyczny i bardzo szybki framework HORSE.
* **Konfiguracja w locie:** Odczyt parametrów z zewnętrznego pliku 'config.json'.

---

## Diagram Architektury

Poniższy schemat przedstawia przepływ danych i zależności w aplikacji:

```text
                      +-----------------------------+
                      |         config.json         |
                      |  (Ustawienia, Typ Bazy DB)  |
                      +--------------+--------------+
                                     |
                                     v
+----------------+    +-----------------------------+    +----------------+
|  IAppLogger    |<---|   KONTENER DI (TContainer)  |--->|   IAppConfig   |
| (Logi systemu) |    |  (Rejestracja Interfejsów)  |    | (Parsowanie DB)|
+----------------+    +--------------+--------------+    +----------------+
                                     |
                                     v
                      +-----------------------------+
                      |       IDatabaseManager      |
                      |   (Zarządzanie połączeniami)|
                      +-+-------+---------+-------+-+
                        |       |         |       |
                  +-----v--++---v- --++---v--++---v-----+
                  | SQLite || Oracle || MSSQL|| Firebird|
                  +--------++--------++------++---------+
                                     ^
                                     |
                      +--------------+--------------+
  Zapytanie HTTP GET  |   Framework HORSE (API)     |  Odpowiedź JSON
--------------------->|   Endpoint: /api/data       |--------------------->
                      +-----------------------------+