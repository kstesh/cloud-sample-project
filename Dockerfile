# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY SampleWebApiAspNetCore/SampleWebApiAspNetCore.csproj SampleWebApiAspNetCore/
RUN dotnet restore SampleWebApiAspNetCore/SampleWebApiAspNetCore.csproj

COPY SampleWebApiAspNetCore/ SampleWebApiAspNetCore/
RUN dotnet publish SampleWebApiAspNetCore/SampleWebApiAspNetCore.csproj \
    -c Release \
    -o /app/publish \
    --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Development
EXPOSE 5000

ENTRYPOINT ["dotnet", "SampleWebApiAspNetCore.dll"]
