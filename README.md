<p align="center">
  <img src="https://github.com/user-attachments/assets/41dd6587-9f3c-45cd-b6b4-e144dc4338ac" alt="godot-spacetimedb_128" width="128">
</p>

## SpacetimeDB Godot SDK for SpacetimeDB 2.x+

> Tested with: `Godot 4.6.1` and `SpacetimeDB 2.x+`

This SDK provides the necessary tools to integrate your Godot Engine project with a SpacetimeDB backend, enabling real-time data synchronization and server interaction directly from your Godot client.

## Documentation

-   [How to install the SpacetimeDB SDK addon](docs/installation.md)
-   [Quick Start guide](docs/quickstart.md)
-   [API Reference](docs/api.md)

## Limitations & TODO

-   **Option<T> and Vec<T>** Currently limited to 1 layer of nesting: Option<Vec<T>>, Vec<Option<T>> only. No Option<Option<T>> or Vec<Vec<T>> etc...
-   **Error Handling:** Can be improved
-   **Configuration:** More options could be added (timeouts, reconnection).
-   **Compression:** Brotli - not supported.
-   **Tables and Views without Primary_key:** only the Insert and Delete callbacks get called. Data will not be saved inside the local DB.
-   **Procedures**: not supported (waiting for a PR for SpacetimeDB to release)
-   **Event Tables**: not supported (waiting for a PR for SpacetimeDB to release)

## Contributing

Code of Conduct: Adhere to the Godot [Code of Conduct](https://godotengine.org/code-of-conduct/) and [GDScript style guide](https://docs.godotengine.org/en/4.4/tutorials/scripting/gdscript/gdscript_styleguide.html). As a contributor, it is important to respect and follow these to maintain positive collaboration and clean code.

## License

This project is licensed under the MIT License.
