---
name: dotnet:blazor-patterns
description: Blazor Server/WASM/Auto render modes, streaming SSR, state management, forms, JS interop, lifecycle, SignalR. Auto-loads for .razor work.
effort: medium
---

# blazor-patterns

Blazor component architecture for .NET 8–11.

## Iron Laws

- **#19**: `StateHasChanged` from non-UI thread needs `InvokeAsync(...)`
- **#20**: `@key` on dynamic lists
- **#21**: No secrets in Blazor WASM — all code ships to browser
- **#22**: Dispose timers/subscriptions in `IDisposable`/`IAsyncDisposable`

## Render Modes (.NET 8+)

| Mode | When | Trade-off |
|------|------|-----------|
| Static SSR (default) | Content pages | No interactivity |
| InteractiveServer | Dashboards, admin, real-time | Circuit overhead |
| InteractiveWebAssembly | Offline-capable, fewer server calls | Slower first load |
| InteractiveAuto | Best of both (SSR prerender → WASM hydrate) | Complex state transfer |

Set per-component or globally in `App.razor`.

## Core Patterns

### Component with state

```razor
@page "/orders"
@rendermode InteractiveServer
@inject IOrderService OrderService
@implements IAsyncDisposable

<h3>Orders</h3>

@if (isLoading) { <Loading /> }
else
{
    <table>
        @foreach (var order in orders)
        {
            <OrderRow @key="order.Id" Order="order" />
        }
    </table>
}

@code {
    private List<OrderDto> orders = [];
    private bool isLoading = true;
    private readonly CancellationTokenSource _cts = new();

    protected override async Task OnInitializedAsync()
    {
        orders = await OrderService.ListAsync(_cts.Token);
        isLoading = false;
    }

    public async ValueTask DisposeAsync()
    {
        _cts.Cancel();
        _cts.Dispose();
        await Task.CompletedTask;
    }
}
```

### Thread-safe StateHasChanged

```razor
@code {
    protected override void OnInitialized()
    {
        Notifications.OnOrderUpdated += HandleOrderUpdated;
    }

    private async void HandleOrderUpdated(object? sender, OrderEventArgs e)
    {
        // Called from non-UI thread — must InvokeAsync
        await InvokeAsync(() =>
        {
            UpdateLocalOrder(e.Order);
            StateHasChanged();
        });
    }
}
```

### Streaming SSR (.NET 8+)

```razor
@page "/orders/{Id:long}"
@attribute [StreamRendering(true)]

<h3>Order @Id</h3>

@if (order is null) { <p>Loading...</p> }
else { <OrderDetail Order="order" /> }

@code {
    [Parameter] public long Id { get; set; }
    private OrderDto? order;

    protected override async Task OnInitializedAsync()
    {
        order = await OrderService.GetAsync(Id);  // HTML streams when this resolves
    }
}
```

### Forms with FluentValidation

```razor
<EditForm Model="@model" OnValidSubmit="@HandleSubmit">
    <FluentValidationValidator />
    <InputText @bind-Value="model.Name" />
    <ValidationMessage For="@(() => model.Name)" />
    <button type="submit" disabled="@isSubmitting">Save</button>
</EditForm>
```

### JS Interop with disposal

```razor
@inject IJSRuntime JS
@implements IAsyncDisposable

@code {
    private IJSObjectReference? module;
    private ElementReference gridEl;

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            module = await JS.InvokeAsync<IJSObjectReference>("import", "./js/grid.js");
            await module.InvokeVoidAsync("init", gridEl);
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (module is not null)
        {
            await module.InvokeVoidAsync("destroy");
            await module.DisposeAsync();
        }
    }
}
```

## References

- `${CLAUDE_SKILL_DIR}/references/render-modes.md` — mode selection + examples
- `${CLAUDE_SKILL_DIR}/references/state-management.md` — cascading, DI,
  PersistentComponentState
- `${CLAUDE_SKILL_DIR}/references/forms.md` — EditForm, validation,
  SupplyParameterFromForm
- `${CLAUDE_SKILL_DIR}/references/js-interop.md` — module patterns,
  disposal, WASM in-process
- `${CLAUDE_SKILL_DIR}/references/lifecycle.md` — OnInit/OnParametersSet/
  OnAfterRender
- `${CLAUDE_SKILL_DIR}/references/streaming-ssr.md` — StreamRendering
  attribute

## Anti-patterns

- Business logic in `.razor.cs` — move to services
- Missing `@key` on `@foreach` with reorderable list (Iron Law #20)
- `async void` handlers that throw (swallowed — crashes later)
- Holding DbContext in component for circuit lifetime — Scoped = per
  component but long-lived circuit can exhaust connections
- Direct secrets in WASM client code (Iron Law #21)
