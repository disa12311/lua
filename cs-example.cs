using System.Text.Json;
using System.Net.Http.Json;

public async Task FetchScripts() {
    HttpClient client = new HttpClient();
    try {
        JsonElement scripts = await client.GetFromJsonAsync<JsonElement>("https://scriptblox.com/api/script/search?q=admin"); // 20 most recent scripts that relate to "admin"
        foreach(JsonElement script in scripts.GetProperty("result").GetProperty("scripts")) {
            // Use the script to, for example, display it in a window/page
            Application.Current.Dispatcher.Invoke(() => {
                // Example: ScriptPanel is a StackPanel defined in your XAML
                ScriptPanel.Children.Add(new TextBlock(){
                    Text = $"Title: {script.GetProperty("title").GetString()}\nSlug: \n{script.GetProperty("slug").GetString()}"
                });
            });
        }
    }
    catch (HttpRequestException e)
    {
        // Network error or invalid URL
        Application.Current.Dispatcher.Invoke(() =>
        {
            ScriptPanel.Children.Add(new TextBlock()
            {
                Text = $"Network error while fetching scripts:\n{e.Message}",
                Margin = new Thickness(10)
            });
        });
    }
    catch (JsonException e)
    {
        // JSON parsing error
        Application.Current.Dispatcher.Invoke(() =>
        {
            ScriptPanel.Children.Add(new TextBlock()
            {
                Text = $"Error parsing JSON response:\n{e.Message}",
                Margin = new Thickness(10)
            });
        });
    }
    catch (Exception e)
    {
        // General exception
        Application.Current.Dispatcher.Invoke(() =>
        {
            ScriptPanel.Children.Add(new TextBlock()
            {
                Text = $"Unexpected error:\n{e.Message}",
                Margin = new Thickness(10)
            });
        });
    }
}

