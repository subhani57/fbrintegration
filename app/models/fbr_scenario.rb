# app/models/fbr_scenario.rb
class FbrScenario < ApplicationRecord
  SCENARIOS = {
    'SN001' => 'Goods at standard rate to registered buyers',
    'SN002' => 'Goods at standard rate to unregistered buyers',
    'SN003' => 'Sale of Steel (Melted and Re-Rolled)',
    'SN004' => 'Sale by Ship Breakers',
    'SN005' => 'Reduced rate sale',
    'SN006' => 'Exempt goods sale',
    'SN007' => 'Zero rated sale',
    'SN008' => 'Sale of 3rd schedule goods',
    'SN009' => 'Cotton Spinners purchase from Cotton Ginners',
    'SN010' => 'Telecom services rendered or provided',
    'SN011' => 'Toll Manufacturing sale by Steel sector',
    'SN012' => 'Sale of Petroleum products',
    'SN013' => 'Electricity Supply to Retailers',
    'SN014' => 'Sale of Gas to CNG stations',
    'SN015' => 'Sale of mobile phones',
    'SN016' => 'Processing / Conversion of Goods',
    'SN017' => 'Sale of Goods where FED is charged in ST mode',
    'SN018' => 'Services rendered or provided where FED is charged in ST mode',
    'SN019' => 'Services rendered or provided',
    'SN020' => 'Sale of Electric Vehicles',
    'SN021' => 'Sale of Cement /Concrete Block',
    'SN022' => 'Sale of Potassium Chlorate',
    'SN023' => 'Sale of CNG',
    'SN024' => 'Goods sold that are listed in SRO 297(1)/2023',
    'SN025' => 'Drugs sold at fixed ST rate under serial 81 of Eighth Schedule',
    'SN026' => 'Sale to End Consumer by retailers',
    'SN027' => 'Sale to End Consumer by retailers (3rd Schedule Goods)',
    'SN028' => 'Sale to End Consumer by retailers (Reduced Rate)'
  }.freeze
end
