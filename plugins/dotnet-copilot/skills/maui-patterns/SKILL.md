---
name: maui-patterns
description: .NET MAUI patterns — MVVM via CommunityToolkit.Mvvm, Shell navigation, DI, platform services, CollectionView. Auto-loads for MAUI Page/ViewModel/MauiProgram work.
effort: medium
---

# maui-patterns

.NET MAUI cross-platform patterns for .NET 8–11.

## Iron Laws

- **#2**: No `.Result` / `.Wait()` — deadlocks on UI sync context
- **#23**: MVVM — no logic in code-behind
- **#24**: `ObservableCollection<T>` for bindable lists
- **#25**: Weak events for long-lived publishers

## Bootstrap

```csharp
// MauiProgram.cs
public static MauiApp CreateMauiApp()
{
    var builder = MauiApp.CreateBuilder();
    builder
        .UseMauiApp<App>()
        .ConfigureFonts(f => f.AddFont("Inter-Regular.ttf", "Inter"));

    builder.Services
        .AddSingleton<AppShell>()
        .AddHttpClient<IOrderService, OrderService>(c =>
            c.BaseAddress = new(builder.Configuration["ApiBaseUrl"]!))
        .AddSingleton<INavigationService, ShellNavigationService>()
        .AddTransient<OrdersPage>()
        .AddTransient<OrdersViewModel>()
        .AddTransient<OrderDetailPage>()
        .AddTransient<OrderDetailViewModel>();

#if ANDROID
    builder.Services.AddSingleton<IPhotoService, AndroidPhotoService>();
#elif IOS || MACCATALYST
    builder.Services.AddSingleton<IPhotoService, ApplePhotoService>();
#endif

    return builder.Build();
}
```

## ViewModel with CommunityToolkit.Mvvm

```csharp
public partial class OrdersViewModel(IOrderService svc) : ObservableObject
{
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _searchText;
    public ObservableCollection<OrderDto> Orders { get; } = [];

    [RelayCommand]
    private async Task LoadAsync(CancellationToken ct)
    {
        IsBusy = true;
        try
        {
            Orders.Clear();
            foreach (var o in await svc.ListAsync(SearchText, ct))
                Orders.Add(o);
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private Task OpenAsync(OrderDto order) =>
        Shell.Current.GoToAsync($"orders/detail?id={order.Id}");
}
```

## Shell Navigation

```xml
<Shell xmlns="http://schemas.microsoft.com/dotnet/2021/maui">
    <TabBar>
        <Tab Title="Orders" Icon="orders.png">
            <ShellContent ContentTemplate="{DataTemplate local:OrdersPage}" />
        </Tab>
    </TabBar>
</Shell>
```

```csharp
// App.xaml.cs
Routing.RegisterRoute("orders/detail", typeof(OrderDetailPage));
```

```csharp
// Receiving VM
[QueryProperty(nameof(OrderId), "id")]
public partial class OrderDetailViewModel : ObservableObject
{
    [ObservableProperty] private long _orderId;

    partial void OnOrderIdChanged(long value) => _ = LoadAsync();
}
```

## Data-binding

```xml
<ContentPage xmlns:vm="clr-namespace:App.ViewModels"
             x:DataType="vm:OrdersViewModel">
    <CollectionView ItemsSource="{Binding Orders}">
        <CollectionView.ItemTemplate>
            <DataTemplate x:DataType="vm:OrderDto">
                <Grid Padding="12">
                    <Label Text="{Binding Id}" />
                    <Label Text="{Binding Total, StringFormat='{0:C}'}" />
                </Grid>
            </DataTemplate>
        </CollectionView.ItemTemplate>
    </CollectionView>
</ContentPage>
```

## Platform Services

```csharp
// Shared
public interface IPhotoService
{
    Task<Stream?> PickAsync(CancellationToken ct);
}

// Platforms/Android/Services/AndroidPhotoService.cs
public class AndroidPhotoService : IPhotoService
{
    public async Task<Stream?> PickAsync(CancellationToken ct)
    {
        var result = await MediaPicker.Default.PickPhotoAsync();
        return result is null ? null : await result.OpenReadAsync();
    }
}
```

## Storage

```csharp
// Secrets: Keychain / Keystore
await SecureStorage.Default.SetAsync("api_token", token);
var token = await SecureStorage.Default.GetAsync("api_token");

// Non-secret prefs
Preferences.Default.Set("theme", "dark");
```

## References

- `${CLAUDE_SKILL_DIR}/references/mvvm.md` — ObservableProperty,
  RelayCommand, validation
- `${CLAUDE_SKILL_DIR}/references/navigation.md` — Shell, routing,
  deep-linking
- `${CLAUDE_SKILL_DIR}/references/platform-services.md` — platform
  abstraction patterns
- `${CLAUDE_SKILL_DIR}/references/collectionview.md` — virtualization,
  grouping, paging
- `${CLAUDE_SKILL_DIR}/references/performance.md` — AOT, startup, image
  caching
- `${CLAUDE_SKILL_DIR}/references/storage.md` — SecureStorage,
  Preferences, SQLite

## Anti-patterns

- Code-behind with business logic (Iron Law #23)
- `Application.Current.MainPage` deep in VMs — untestable
- Using `List<T>` instead of `ObservableCollection<T>` for bound list
  (Iron Law #24)
- Blocking on `Task.Result` in MauiProgram (deadlock on iOS)
- Platform code via `#if` spaghetti instead of interface abstraction
