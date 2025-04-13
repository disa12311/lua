
fetch("https://scriptblox.com/api/script/search?q=admin"); // 20 most recent scripts that relate to "admin"
    .then((res) => res.json())
    .then((data) => {
        // Example: the page contains an element with id="results"
        const results = document.getElementById('results');

        // Loop through the scripts and display them on the page
        for (const script of data.result.scripts) {
            // Create a new div to hold each script's information
            const scriptElement = document.createElement('div');
            scriptElement.classList.add('script');

            // Add script title
            const titleElement = document.createElement('h3');
            titleElement.textContent = `Title: ${script.title}`;
            scriptElement.appendChild(titleElement);

            // Add script slug
            const slugElement = document.createElement('p');
            slugElement.textContent = `Slug: ${script.slug}`;
            scriptElement.appendChild(slugElement);

            // Add the script to the container
            scriptsContainer.appendChild(scriptElement);
        }
    })
    .catch((error) => {
        console.error('Error while fetching scripts', error);
        // Display an error message on the page
        const errorMessage = document.createElement('p');
        errorMessage.textContent = `Error while fetching scripts: ${error.message}`;
        document.getElementById('results').appendChild(errorMessage);
    });

