import Foundation

/// Sample payloads copied from the shape API-Football returns, trimmed to what LineupLab reads.
enum SampleJSON {

    static let fixtures = """
    {
      "get": "fixtures",
      "parameters": { "date": "2026-09-11" },
      "errors": [],
      "results": 2,
      "paging": { "current": 1, "total": 1 },
      "response": [
        {
          "fixture": {
            "id": 1001,
            "referee": "A. Fielding",
            "timezone": "UTC",
            "date": "2026-09-11T14:00:00+00:00",
            "timestamp": 1789048800,
            "periods": { "first": 1789048800, "second": 1789052400 },
            "venue": { "id": 556, "name": "Riverside Stadium", "city": "Riverside" },
            "status": { "long": "Second Half", "short": "2H", "elapsed": 67 }
          },
          "league": {
            "id": 39,
            "name": "Premier League",
            "country": "England",
            "logo": "https://media.api-sports.io/football/leagues/39.png",
            "flag": "https://media.api-sports.io/flags/gb.svg",
            "season": 2026,
            "round": "Regular Season - 4"
          },
          "teams": {
            "home": { "id": 33, "name": "Riverside United", "logo": "https://media.api-sports.io/football/teams/33.png", "winner": true },
            "away": { "id": 40, "name": "Northgate City", "logo": "https://media.api-sports.io/football/teams/40.png", "winner": false }
          },
          "goals": { "home": 2, "away": 1 },
          "score": {
            "halftime": { "home": 1, "away": 1 },
            "fulltime": { "home": null, "away": null },
            "extratime": { "home": null, "away": null },
            "penalty": { "home": null, "away": null }
          }
        },
        {
          "fixture": {
            "id": 1002,
            "referee": null,
            "timezone": "UTC",
            "date": "2026-09-11T19:45:00+00:00",
            "timestamp": 1789069500,
            "periods": { "first": null, "second": null },
            "venue": { "id": null, "name": null, "city": null },
            "status": { "long": "Not Started", "short": "NS", "elapsed": null }
          },
          "league": {
            "id": 1,
            "name": "World Cup",
            "country": "World",
            "logo": "https://media.api-sports.io/football/leagues/1.png",
            "flag": null,
            "season": 2026,
            "round": "Group Stage - 1"
          },
          "teams": {
            "home": { "id": 6, "name": "Brazil", "logo": null, "winner": null },
            "away": { "id": 2, "name": "France", "logo": null, "winner": null }
          },
          "goals": { "home": null, "away": null },
          "score": {
            "halftime": { "home": null, "away": null },
            "fulltime": { "home": null, "away": null },
            "extratime": { "home": null, "away": null },
            "penalty": { "home": null, "away": null }
          }
        }
      ]
    }
    """

    static let lineups = """
    {
      "get": "fixtures/lineups",
      "parameters": { "fixture": "1001" },
      "errors": [],
      "results": 2,
      "paging": { "current": 1, "total": 1 },
      "response": [
        {
          "team": { "id": 33, "name": "Riverside United", "logo": null, "colors": null },
          "coach": { "id": 9, "name": "R. Calder", "photo": null },
          "formation": "4-3-3",
          "startXI": [
            { "player": { "id": 1, "name": "Ivan Petrov", "number": 1, "pos": "G", "grid": "1:1" } },
            { "player": { "id": 2, "name": "Tomas Vidal", "number": 2, "pos": "D", "grid": "2:1" } },
            { "player": { "id": 3, "name": "Marcus Fell", "number": 5, "pos": "D", "grid": "2:2" } },
            { "player": { "id": 4, "name": "Yannick Boye", "number": 6, "pos": "D", "grid": "2:3" } },
            { "player": { "id": 5, "name": "Diego Salas", "number": 3, "pos": "D", "grid": "2:4" } },
            { "player": { "id": 6, "name": "Ken Ito", "number": 8, "pos": "M", "grid": "3:1" } },
            { "player": { "id": 7, "name": "Luc Bertrand", "number": 4, "pos": "M", "grid": "3:2" } },
            { "player": { "id": 8, "name": "Samir Haddad", "number": 10, "pos": "M", "grid": "3:3" } },
            { "player": { "id": 9, "name": "Rafael Moreno", "number": 11, "pos": "F", "grid": "4:1" } },
            { "player": { "id": 10, "name": "Owen Blake", "number": 9, "pos": "F", "grid": "4:2" } },
            { "player": { "id": 11, "name": "Kwame Asante", "number": 7, "pos": "F", "grid": "4:3" } }
          ],
          "substitutes": [
            { "player": { "id": 12, "name": "Reserve Keeper", "number": 13, "pos": "G", "grid": null } },
            { "player": { "id": 13, "name": "Reserve Mid", "number": 14, "pos": "M", "grid": null } }
          ]
        },
        {
          "team": { "id": 40, "name": "Northgate City", "logo": null, "colors": null },
          "coach": { "id": 19, "name": "P. Novak", "photo": null },
          "formation": "4-2-3-1",
          "startXI": [
            { "player": { "id": 21, "name": "Nils Berger", "number": 1, "pos": "G", "grid": "1:1" } }
          ],
          "substitutes": []
        }
      ]
    }
    """

    static let fixturePlayers = """
    {
      "get": "fixtures/players",
      "parameters": { "fixture": "1001" },
      "errors": [],
      "results": 1,
      "paging": { "current": 1, "total": 1 },
      "response": [
        {
          "team": { "id": 33, "name": "Riverside United", "logo": null },
          "players": [
            {
              "player": { "id": 9, "name": "Rafael Moreno", "photo": null },
              "statistics": [
                {
                  "games": { "minutes": 90, "number": 11, "position": "F", "rating": "8.4", "captain": false, "substitute": false },
                  "offsides": 1,
                  "shots": { "total": 5, "on": 3 },
                  "goals": { "total": 2, "conceded": 0, "assists": 1, "saves": null },
                  "passes": { "total": 41, "key": 4, "accuracy": "82" },
                  "tackles": { "total": 1, "blocks": null, "interceptions": 2 },
                  "duels": { "total": 14, "won": 9 },
                  "dribbles": { "attempts": 7, "success": 5, "past": null },
                  "fouls": { "drawn": 3, "committed": 1 },
                  "cards": { "yellow": 0, "red": 0 }
                }
              ]
            },
            {
              "player": { "id": 10, "name": "Owen Blake", "photo": null },
              "statistics": [
                {
                  "games": { "minutes": 58, "number": 9, "position": "F", "rating": null, "captain": false, "substitute": true },
                  "offsides": null,
                  "shots": { "total": null, "on": null },
                  "goals": { "total": null, "conceded": null, "assists": null, "saves": null },
                  "passes": { "total": 12, "key": 0, "accuracy": 75 },
                  "tackles": { "total": null, "blocks": null, "interceptions": null },
                  "duels": { "total": 4, "won": 1 },
                  "dribbles": { "attempts": 1, "success": 0, "past": null },
                  "fouls": { "drawn": null, "committed": 2 },
                  "cards": { "yellow": 1, "red": 0 }
                }
              ]
            }
          ]
        }
      ]
    }
    """

    static let playerProfile = """
    {
      "get": "players",
      "parameters": { "id": "276", "season": "2026" },
      "errors": [],
      "results": 1,
      "paging": { "current": 1, "total": 1 },
      "response": [
        {
          "player": {
            "id": 276,
            "name": "Rafael Moreno",
            "firstname": "Rafael",
            "lastname": "Moreno",
            "age": 24,
            "birth": { "date": "2002-02-05", "place": "Riverside", "country": "Brazil" },
            "nationality": "Brazil",
            "height": "175 cm",
            "weight": "68 kg",
            "injured": false,
            "photo": "https://media.api-sports.io/football/players/276.png"
          },
          "statistics": [
            {
              "team": { "id": 33, "name": "Riverside United", "logo": null },
              "league": { "id": 39, "name": "Premier League", "country": "England", "logo": null, "flag": null, "season": 2026 },
              "games": { "appearences": 28, "lineups": 25, "minutes": 2240, "number": null, "position": "Attacker", "rating": "7.833333", "captain": false },
              "goals": { "total": 14, "conceded": 0, "assists": 7, "saves": null },
              "cards": { "yellow": 3, "yellowred": 0, "red": 0 }
            },
            {
              "team": { "id": 33, "name": "Riverside United", "logo": null },
              "league": { "id": 2, "name": "Champions League", "country": "World", "logo": null, "flag": null, "season": 2026 },
              "games": { "appearences": 6, "lineups": 5, "minutes": 420, "number": null, "position": "Attacker", "rating": "8.1", "captain": false },
              "goals": { "total": 4, "conceded": 0, "assists": 1, "saves": null },
              "cards": { "yellow": 0, "yellowred": 0, "red": 0 }
            }
          ]
        }
      ]
    }
    """

    /// API-Football answers 200 with a dictionary in `errors` when the token is wrong.
    static let tokenError = """
    {
      "get": "fixtures",
      "parameters": [],
      "errors": { "token": "Error/Missing application key." },
      "results": 0,
      "paging": { "current": 1, "total": 1 },
      "response": []
    }
    """

    static let rateLimitError = """
    {
      "get": "fixtures",
      "parameters": [],
      "errors": { "requests": "You have reached the request limit for the day" },
      "results": 0,
      "paging": { "current": 1, "total": 1 },
      "response": []
    }
    """

    static let events = """
    {
      "get": "fixtures/events",
      "parameters": { "fixture": "1001" },
      "errors": [],
      "results": 2,
      "paging": { "current": 1, "total": 1 },
      "response": [
        {
          "time": { "elapsed": 45, "extra": 2 },
          "team": { "id": 33, "name": "Riverside United", "logo": null },
          "player": { "id": 8, "name": "Samir Haddad" },
          "assist": { "id": null, "name": null },
          "type": "Card",
          "detail": "Yellow Card",
          "comments": null
        },
        {
          "time": { "elapsed": 12, "extra": null },
          "team": { "id": 33, "name": "Riverside United", "logo": null },
          "player": { "id": 9, "name": "Rafael Moreno" },
          "assist": { "id": 6, "name": "Ken Ito" },
          "type": "Goal",
          "detail": "Normal Goal",
          "comments": null
        }
      ]
    }
    """

    static let statistics = """
    {
      "get": "fixtures/statistics",
      "parameters": { "fixture": "1001" },
      "errors": [],
      "results": 1,
      "paging": { "current": 1, "total": 1 },
      "response": [
        {
          "team": { "id": 33, "name": "Riverside United", "logo": null },
          "statistics": [
            { "type": "Shots on Goal", "value": 6 },
            { "type": "Total Shots", "value": 14 },
            { "type": "Ball Possession", "value": "58%" },
            { "type": "Red Cards", "value": null },
            { "type": "Passes %", "value": "87%" }
          ]
        }
      ]
    }
    """

    static func data(_ string: String) -> Data {
        Data(string.utf8)
    }
}
