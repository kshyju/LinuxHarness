# Stage 1: Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

# Install clang and zlib1g-dev
RUN apt-get update \
    && apt-get install -y clang zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Install dotnet-trace tool globally
RUN dotnet tool install --global dotnet-trace

# Copy contents of "drop" folder into the container
COPY drop /app/drop

# Clone the worker harness
RUN git clone --branch shkr/harness_20240214_net8 https://github.com/Azure/azure-functions-host.git /app/source/azure-functions-host

WORKDIR /app/source/azure-functions-host/tools/WorkerHarness/src/WorkerHarness.Console

# Build Harness project
RUN dotnet publish -c Release -o /app/drop/harness 

# Clone the Azure Functions .NET Worker repository
RUN git clone --branch shkr/fnh-event-logging_and_load_library https://github.com/Azure/azure-functions-dotnet-worker.git /app/source/azure-functions-dotnet-worker

# Change working directory to the FunctionsNetHost
WORKDIR /app/source/azure-functions-dotnet-worker/host/src/FunctionsNetHost

# Build the FunctionsNetHost project
RUN dotnet publish -c Release -o /app/drop/harness/FunctionsNetHost 

# Get dotnet 6 runtime.
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS runtime6

# Final stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime8

# Set the working directory
WORKDIR /app

# Copy contents of the "drop" folder from the build stage
COPY --from=build /app/drop /app/drop

# Copy .NET 6 runtime from the runtime6 stage
COPY --from=runtime6 /usr/share/dotnet /usr/share/dotnet

# Copy .NET tools from the build stage
COPY --from=build /root/.dotnet/tools /root/.dotnet/tools

# Add .NET tools to PATH
ENV PATH="/root/.dotnet/tools:${PATH}"

# Make sure the necessary permissions are set
RUN chmod -R 777 /app/drop/harness/FunctionsNetHost/FunctionsNetHost

WORKDIR /app/drop/harness/

# Command to run the FunctionsNetHost (for .NET 6.0)
CMD ["dotnet", "Microsoft.Azure.Functions.Worker.Harness.dll"]
