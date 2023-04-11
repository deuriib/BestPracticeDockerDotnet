# Use the .NET Core 7.0 runtime dependencies image on Alpine Linux as the base image
FROM mcr.microsoft.com/dotnet/runtime-deps:7.0-alpine AS base

# Set the working directory for the application
WORKDIR /app

# Expose port 5000 for the application
EXPOSE 5000 

# Set an environment variable to specify the URL for the application
ENV ASPNETCORE_URLS=http://+:5000

# Add the necessary packages for the application and upgrade krb5-libs
RUN apk add --no-cache curl\
    && apk upgrade krb5-libs

# Define a health check for the application using curl to check the endpoint at http://localhost:5000/weatherforecast
HEALTHCHECK CMD curl --fail http://localhost:5000/weatherforecast || exit 1

# Create a non-root user with an explicit UID and add permission to access the /app folder
# For more info, please refer to https://aka.ms/vscode-docker-dotnet-configure-containers
RUN adduser -u 5678 --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

# Use the .NET Core 7.0 SDK on Alpine Linux to build the application
FROM mcr.microsoft.com/dotnet/sdk:7.0-alpine AS build
WORKDIR /src

# Copy the project file and restore the dependencies
COPY ["BestPracticeDockerApi.csproj", "./"]
RUN dotnet restore "BestPracticeDockerApi.csproj" -r linux-musl-arm64 /p:PublishReadyToRun=true

# Copy the application files and build the application
COPY . .
WORKDIR "/src/."
RUN dotnet build "BestPracticeDockerApi.csproj" -c Release -r linux-musl-arm64 -o /app/build

# Use the previous build stage to publish the application
FROM build AS publish
RUN dotnet publish "BestPracticeDockerApi.csproj" --no-restore -c Release -r linux-musl-arm64 --self-contained /p:PublishTrimmed=true /p:PublishReadyToRun=true /P:PublishSingleFile=true  -o /app/publish /p:UseAppHost=true

# Use the base stage as the final stage for the application
FROM base AS final
WORKDIR /app

# Copy the published application files from the previous stage
COPY --from=publish /app/publish .

# Set the entry point for the application
ENTRYPOINT ["./BestPracticeDockerApi"]
