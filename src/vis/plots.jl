function calculate_dc_losses(branches::Dict{String,Any})
    losses = Dict{String,Float64}()
    for (i, branch) in branches
        losses[i] = branch["pf"]^2 * branch["br_r"]
    end

    return losses
end

function calculate_ac_losses(branches::Dict{String,Any})
    losses = Dict{String,Float64}()
    for (i, branch) in branches
        losses[i] = sqrt((branch["pf"] + branch["pt"])^2 + (branch["qf"] + branch["qt"])^2)
    end

    return losses
end

function calculate_region_prices(data, rrn)
    prices = Dict()
    for (region, bus) in rrn
        prices[region] = data["bus"]["$(bus)"]["lam_kcl_r"]
    end
    return prices
end

function plot_losses(dc_data, ac_data)
    dc_losses = calculate_dc_losses(dc_data["branch"])
    ac_losses = calculate_ac_losses(ac_data["branch"])

    trace = [
        histogram(name="DC Model", x=collect(values(dc_losses))),
        histogram(name="AC Model", x=collect(values(ac_losses)), opacity=0.6)
    ]

    layout = Layout(
        barmode="overlay",
        title_text="Branch Losses",
        xaxis_title="MW (p.u)",
        yaxis_title="Count",
        plot_bgcolor="white",
        xaxis=attr(showline=true, linecolor="black"),
        yaxis=attr(showline=true,
            linecolor="black",
            showgrid=true,
            gridwidth=0.5,
            gridcolor="lightgray")
    )

    fig = plot(trace, layout)
    relayout!(fig, template=:plotly_white)
    display(fig)
end

function plot_prices(dc_data, ac_data)
    sorted_buses(data) = sort(collect(data["bus"]), by = x -> x[2]["index"])
    prices(data) = [bus["lam_kcl_r"] for (i, bus) in sorted_buses(data)]
    dc_prices = prices(dc_data)
    ac_prices = prices(ac_data)

    trace = [
        scatter(name="DC Model", x=1:length(dc_prices), y=dc_prices, text=keys(sorted_buses(dc_data)), hovertemplate="bus: %{text}\nprice: \$%{y,.2f}", mode="markers"),
        scatter(name="AC Model", x=1:length(ac_prices), y=ac_prices, text=keys(sorted_buses(ac_data)), hovertemplate="bus: %{text}\nprice: \$%{y,.2f}", mode="markers")
    ]

    layout = Layout(
        title_text="Locational Prices",
        xaxis_title="Bus",
        yaxis_title="Price (\$/MWh)",
        yaxis_range=[-1000, 15000],
        plot_bgcolor="white",
        xaxis=attr(showline=true, linecolor="black"),
        yaxis=attr(showline=true,
            linecolor="black",
            showgrid=true,
            gridwidth=0.5,
            gridcolor="lightgray")
    )

    plot(trace, layout)
end

function plot_voltages(data)
    voltages = [bus["vm"] for (i, bus) in data["bus"]]

    bins = 200
    trace = histogram(x=voltages, nbinsx=bins)
    layout = Layout(
        title_text="Bus Voltage",
        xaxis_title="Bus Voltage (p.u.)",
        yaxis_title="Count",
        plot_bgcolor="white",
        xaxis=attr(showline=true, linecolor="black"),
        yaxis=attr(showline=true,
            linecolor="black",
            showgrid=true,
            gridwidth=0.5,
            gridcolor="lightgray")
    )

    plot(trace, layout)
end

function plot_line_capacities(dc_data, ac_data)
    sij(data) = [100 * ((sqrt((branch["pf"])^2 + (!isnan(branch["qf"]) ? branch["qf"] : 0)^2)) / branch["rate_a"]) for (i, branch) in data["branch"]]

    trace = [
        histogram(name="DC Model", x=sij(dc_data), opacity=0.6),
        histogram(name="AC Model", x=sij(ac_data), opacity=0.6)
    ]

    layout = Layout(
        barmode="overlay",
        title_text="Line Loading",
        xaxis_title="% line loading",
        yaxis_title="Count",
        plot_bgcolor="white",
        xaxis=attr(showline=true, linecolor="black"),
        yaxis=attr(showline=true,
            linecolor="black",
            showgrid=true,
            gridwidth=0.5,
            gridcolor="lightgray")
    )

    plot(trace, layout)
end

function plot_regional_prices(dc_data, ac_data, rrns)
    dc_prices = calculate_region_prices(dc_data, rrns)
    ac_prices = calculate_region_prices(ac_data, rrns)

    y_values(prices) = collect(values(prices))

    trace = [
        bar(name="DC Model", x=keys(dc_prices), y=y_values(dc_prices), text=y_values(dc_prices), texttemplate="\$%{text:,.2f}", textposition="outside"),
        bar(name="AC Model", x=keys(ac_prices), y=y_values(ac_prices), text=y_values(ac_prices), texttemplate="\$%{text:,.2f}", textposition="outside")
    ]

    layout = Layout(
        barmode="group",
        title_text="Regional Prices",
        xaxis_title="Region",
        yaxis_title="\$/MWh",
        plot_bgcolor="white",
        xaxis=attr(showline=true, linecolor="black"),
        yaxis=attr(showline=true,
            linecolor="black",
            showgrid=true,
            gridwidth=0.5,
            gridcolor="lightgray")
    )

    plot(trace, layout)
end