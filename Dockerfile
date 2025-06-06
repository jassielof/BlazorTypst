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

# Install dependencies for the Typst installation script (curl, tar, xz)
RUN apk update && \
    apk add --no-cache curl tar xz

# Copy the Typst installation script into the image
# Assuming your install.sh is in a directory named 'typst-install' at the root of your build context
COPY typst-install/install.sh /tmp/install-typst.sh

# Make the script executable and run it
# Then, move the typst binary to a standard PATH location
# The script installs to $HOME/.typst/bin by default.
# We'll run it as root, so $HOME will be /root.
RUN chmod +x /tmp/install-typst.sh && \
    /tmp/install-typst.sh && \
    if [ -f /root/.typst/bin/typst ]; then \
      mv /root/.typst/bin/typst /usr/local/bin/typst && \
      chmod a+rx /usr/local/bin/typst; \
    else \
      echo "Typst binary not found in /root/.typst/bin after installation." && exit 1; \
    fi && \
    rm /tmp/install-typst.sh && \
    typst --version

ENV PATH="/usr/local/bin:${PATH}"

# Copy published app
COPY --from=build /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:80
ENV ASPNETCORE_ENVIRONMENT=Production

# Create non-root user for security
RUN adduser -u 5678 -D appuser && chown -R appuser /app
USER appuser

ENTRYPOINT ["dotnet", "BlazorTypst.dll"]
