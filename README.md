AYON Server
===========

Ayon Server is a powerful tool for managing and automating workflow for animation and visual effects.

Requirements
------------

Docker with **compose** plugin. To install the latest Docker, you may use this script: 
https://get.docker.com

If you use stand-alone `docker-compose` script instead of the compose plugin, 
make sure to use `docker-compose` wherever `docker compose` is used in this tutorial.

For the production, using Linux is highly recommended, but for evaluation purposes,
Windows with WSL could be used.

 
Installation
------------

 - Clone this repository to your local machine.
 - Tweak the `docker-compose.yml` file according to your requirements.
 - You may use `.env` file to set environment variables (for example for SSO configuration).
 - On Windows, comment-out or delete  `- "/etc/localtime:/etc/localtime:ro"` line from the `docker-compose.yml`
 - Run the stack using `docker compose up -d`
 - Once the docker is up, navigate to `http://localhost:5000/` in your web browser and follow the onboarding steps presented to you.

### Demo Projects

You can setup a demo which will create 3 project; 
`demo_Commercial`, `demo_Big_Episodic` and `demo_Big_Feature`.

- `make demo` (Unix) or `manage.ps1 demo` (Windows)

**NOTE: These demo projects can take a while to create.**


Development
-----------

To work on the Ayon server code, you need to download the frontend and backend repositories.

### Backend

To start working on the backend, run the following command in your terminal:

```bash
make backend && make frontend
```

After that, uncomment the `-"./backend:/backend"` line in the `docker-compose.yml` file. 
This will mount your local backend to the container. 
You will need to restart the stack by running docker compose down && docker compose up.

To apply your changes to the backend service, run `make reload`.

### Frontend

To work on the frontend code, you need to have Node 18+ and yarn installed on your machine.

Navigate to the `frontend` directory and run `yarn install` and then `yarn dev`. 
This command will start the development server for the frontend on port 3000 by default. 
All API requests will be proxied to the server running on `localhost:5000`.
