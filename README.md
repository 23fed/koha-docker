# Dockerized Koha Library Software
[Koha Community Website](https://koha-community.org/)

## Configuration
The configuration of this application is handled exclusively via the `.env` file. You can customize all instance-specific settings there.

> [!IMPORTANT]
> **Security:** Remember to change the default database username and password in the `docker-compose.yml` file (or within your `.env` if linked) before deployment.

## Deployment
To start the application, run the following command in your terminal:

```bash
docker compose up -d
