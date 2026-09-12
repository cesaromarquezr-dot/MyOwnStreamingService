# Home server backend

The Dart backend exposes the authenticated API used by Flutter. `arm/` contains ARM integration, `routes/` contains HTTP endpoints, `services/` contains business logic, `models/` contains API/domain objects, and `database/` contains the current persistence abstraction.

For a physical deployment, mount the media disks and optical drives into the ARM/server environment and configure the ARM URL and media paths through environment variables.
