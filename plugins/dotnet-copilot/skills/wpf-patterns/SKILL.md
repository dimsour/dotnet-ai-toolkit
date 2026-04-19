---
name: wpf-patterns
description: WPF patterns — MVVM with CommunityToolkit.Mvvm, compiled bindings, DataGrid, resources, behaviors, generic host bootstrap. Auto-loads for WPF Window/XAML work.
effort: medium
---

# wpf-patterns

WPF desktop patterns for .NET 8–11 (net8.0-windows / net10.0-windows).

## Iron Laws

- **#2**: No `.Result` / `.Wait()` — deadlocks on UI sync context
- **#23**: MVVM — no logic in `.xaml.cs`
- **#24**: `ObservableCollection<T>` for bindable lists
- **#25**: Weak events for long-lived publishers

## Bootstrap with Generic Host (.NET 8+)

```csharp
public partial class App : Application
{
    private IHost? _host;

    protected override async void OnStartup(StartupEventArgs e)
    {
        _host = Host.CreateApplicationBuilder()
            .ConfigureServices((ctx, s) =>
            {
                s.AddSingleton<MainWindow>();
                s.AddSingleton<MainViewModel>();
                s.AddTransient<OrderDetailViewModel>();
                s.AddHttpClient<IOrderService, OrderService>();
            }).Build();

        await _host.StartAsync();
        _host.Services.GetRequiredService<MainWindow>().Show();
        base.OnStartup(e);
    }

    protected override async void OnExit(ExitEventArgs e)
    {
        using (_host) { await _host!.StopAsync(); }
        base.OnExit(e);
    }
}
```

Remove `StartupUri` from `App.xaml` when using this pattern.

## ViewModel

```csharp
public partial class OrdersViewModel(IOrderService svc) : ObservableObject, IDisposable
{
    private readonly CancellationTokenSource _cts = new();

    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private OrderDto? _selected;
    public ObservableCollection<OrderDto> Orders { get; } = [];

    [RelayCommand]
    private async Task LoadAsync()
    {
        IsBusy = true;
        try
        {
            Orders.Clear();
            foreach (var o in await svc.ListAsync(_cts.Token))
                Orders.Add(o);
        }
        finally { IsBusy = false; }
    }

    public void Dispose() { _cts.Cancel(); _cts.Dispose(); }
}
```

## Compiled Bindings

```xml
<Window x:Class="App.MainWindow"
        xmlns:vm="clr-namespace:App.ViewModels"
        d:DataContext="{d:DesignInstance vm:MainViewModel}">
    <UserControl x:DataType="vm:OrdersViewModel">
        <DataGrid ItemsSource="{Binding Orders}"
                  SelectedItem="{Binding Selected, Mode=TwoWay}"
                  VirtualizingStackPanel.IsVirtualizing="True"
                  VirtualizingStackPanel.VirtualizationMode="Recycling"
                  EnableRowVirtualization="True"
                  AutoGenerateColumns="False">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Id" Binding="{Binding Id}" />
                <DataGridTextColumn Header="Total"
                                    Binding="{Binding Total, StringFormat='{}{0:C}'}" />
            </DataGrid.Columns>
        </DataGrid>
    </UserControl>
</Window>
```

## Commands

```xml
<Button Content="Reload"
        Command="{Binding LoadCommand}" />

<!-- With parameter -->
<Button Content="Open"
        Command="{Binding OpenCommand}"
        CommandParameter="{Binding Selected}" />
```

## Behaviors / Event→Command

```xml
<xmlns:b="http://schemas.microsoft.com/xaml/behaviors">
<ListBox ItemsSource="{Binding Items}">
    <b:Interaction.Triggers>
        <b:EventTrigger EventName="SelectionChanged">
            <b:InvokeCommandAction Command="{Binding SelectionChangedCommand}" />
        </b:EventTrigger>
    </b:Interaction.Triggers>
</ListBox>
```

## Validation

```csharp
public partial class UserViewModel : ObservableValidator
{
    [ObservableProperty]
    [Required][EmailAddress]
    [NotifyDataErrorInfo]
    private string _email = "";

    [RelayCommand(CanExecute = nameof(CanSave))]
    private void Save() { /* ... */ }

    private bool CanSave() => !HasErrors;
}
```

## Threading

```csharp
// Update UI from background
await Task.Run(async () =>
{
    var data = await FetchDataAsync();
    Application.Current.Dispatcher.Invoke(() =>
    {
        Items.Clear();
        foreach (var item in data) Items.Add(item);
    });
});
```

## References

- `${CLAUDE_SKILL_DIR}/references/mvvm.md` — ObservableObject,
  ObservableValidator, RelayCommand
- `${CLAUDE_SKILL_DIR}/references/data-binding.md` — compiled bindings,
  paths, converters
- `${CLAUDE_SKILL_DIR}/references/commanding.md` — RelayCommand,
  RoutedUICommand, InputBindings
- `${CLAUDE_SKILL_DIR}/references/resources.md` — ResourceDictionary,
  theming, StaticResource vs DynamicResource
- `${CLAUDE_SKILL_DIR}/references/behaviors.md` — Interactivity package,
  custom behaviors
- `${CLAUDE_SKILL_DIR}/references/dependencyproperties.md` — DP
  registration, attached, coerce

## Anti-patterns

- Logic in `*.xaml.cs` beyond `InitializeComponent()` (Iron Law #23)
- Static singleton VM (`MainViewModel.Instance`) instead of DI
- `DataContext = new SomeVM()` in XAML — breaks DI
- Non-virtualized DataGrid on thousands of rows
- Raw event subscriptions without unsubscribe → leaks
- `MessageBox.Show(...)` in VM — untestable, injection of `IDialogService`
  instead
