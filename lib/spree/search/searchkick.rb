module Spree
  module Search
    class Searchkick < Spree::Core::Search::Base
      def retrieve_products
        @products = base_elasticsearch
      end

      def base_elasticsearch
        curr_page = page || 1
        Spree::Product.search(
          keyword_query,
          fields: Spree::Product.search_fields,
          where: where_query,
          aggs: aggregations,
          smart_aggs: true,
          order: sorted,
          page: curr_page,
          per_page: per_page,
        )
      end

      def where_query
        where_query = {
          active: true,
          price: { not: nil },
          currency: current_currency,
        }
        if price
          min_price, max_price = price.split(',')
          where_query[:price] = { gte: min_price, lte: max_price } if max_price.to_i > 0 && min_price.to_i < max_price.to_i
        end
        Spree::OptionType.pluck(:name).each do |option_type|
          where_query[option_type] = Spree::OptionValue.where(id: params[option_type].split(',')).pluck(:name) if params[option_type].present? && params[option_type].split(',').count > 0
        end
        where_query[:taxon_ids] = taxon.id if taxon
        add_search_filters(where_query)
      end

      def keyword_query
        keywords.nil? || keywords.empty? ? "*" : keywords
      end

      def sorted
        order_params = {}
        order_params[:conversions] = :desc if conversions
        case sort_by
        when 'newest-first'
          order_params[:created_at] = :desc
        when 'price-high-to-low'
          order_params[:price] = :desc
        when 'price-low-to-high'
          order_params[:price] = :asc
        else
          order_params[:id] = :asc
        end
        order_params
      end

      def aggregations
        fs = []

        aggregation_classes.each do |agg_class|
          agg_class.filterable.each do |record|
            fs << record.filter_name.to_sym
          end
        end

        fs
      end

      def aggregation_classes
        [
          Spree::Taxonomy, 
          Spree::Property, 
          Spree::OptionType
        ]
      end

      def add_search_filters(query)
        return query unless search
        search.each do |name, scope_attribute|
          query.merge!(Hash[name, scope_attribute])
        end
        query
      end

      def prepare(params)
        super
        @properties[:conversions] = params[:conversions]
        @properties[:params] = params
      end
    end
  end
end
