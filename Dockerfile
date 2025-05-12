FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS build

WORKDIR /src

# Copy csproj and restore dependencies
COPY ["BlazorTypst.csproj", "./"]
RUN dotnet restore

# Copy all files and build
COPY . .
RUN dotnet build "BlazorTypst.csproj" -c Release -o /app/build
RUN dotnet publish "BlazorTypst.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS final
WORKDIR /app
EXPOSE 80
EXPOSE 443

# Install Typst and symlink to PATH
RUN apk add --no-cache xz curl && \
    curl -fsSL https://typst.community/typst-install/install.sh | sh && \
    install -Dm755 /root/.typst/bin/typst /usr/local/bin/typst

# Copy published app
COPY --from=build /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:80;https://+:443
ENV ASPNETCORE_ENVIRONMENT=Production

# Create non-root user for security
RUN adduser -u 5678 -D appuser && chown -R appuser /app
USER appuser

ENTRYPOINT ["dotnet", "BlazorTypst.dll"]
