$source = @"
// Copyright (c) 2010, 2012 Matt Enright

// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

using System;
using System.Linq;

public class Levenshtein {
	public static int EditDistance (string original, string modified)
	{
		if (original == modified)
			return 0;

		int len_orig = original.Length;
		int len_diff = modified.Length;

		if (len_orig == 0)
			return len_diff;

		if (len_diff == 0)
			return len_orig;

		var matrix = new int[len_orig + 1, len_diff + 1];

		for (int i = 1; i <= len_orig; i++) {
			matrix[i, 0] = i;
			for (int j = 1; j <= len_diff; j++) {
				int cost = modified[j - 1] == original[i - 1] ? 0 : 1;
				if (i == 1)
					matrix[0, j] = j;

				var vals = new int[] {
					matrix[i - 1, j] + 1,
					matrix[i, j - 1] + 1,
					matrix[i - 1, j - 1] + cost
				};
				matrix[i,j] = vals.Min ();
				if (i > 1 && j > 1 && original[i - 1] == modified[j - 2] && original[i - 2] == modified[j - 1])
					matrix[i,j] = Math.Min (matrix[i,j], matrix[i - 2, j - 2] + cost);
			}
		}
		return matrix[len_orig, len_diff];
	}
}
"@
$sourceCSV
$columnHeaders

$head = "
    <Title>Dedupe Report</Title>
    <style>
        td, th {
            border: 1px solid black;
            border-collapse: collapse;
        }

        th {
            color:white;
            background-color: #a33039;
        }

        table, tr, td, th {
            padding: 2px; 
            margin: 0px;
        }

        tr:nth-child(odd) {
            background-color: lightgray;
        }

        table {
            width: 95%;
            margin-left: 5px;
            margin-bottom: 20px;
        }
    </style>
    <br />
    <h1>Dedupe Report</h1>
"

$body
$saveChooser

Add-Type -TypeDefinition $source

function initializeForm() {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Size = New-Object System.Drawing.Size(300,150)
    $form.Text = "Select a CSV file"
    $form.StartPosition = "CenterScreen"

    # File Path Label
    $filePathLabel = New-Object System.Windows.Forms.Label
    $filePathLabel.AutoSize = $true
    $filePathLabel.Location = New-Object System.Drawing.Point(10,20)
    $filePathLabel.Size = New-Object System.Drawing.Size(40,20)
    $filePathLabel.Text = "File Path:"
    $form.Controls.Add($filePathLabel)

    # File Path Text Box
    $filePathTextBox = New-Object System.Windows.Forms.TextBox
    $filePathTextBox.Name = "filePathTextBox"
    $filePathTextBox.Location = New-Object System.Drawing.Point(10,40)
    $filePathTextBox.Size = New-Object System.Drawing.Size(180,20)
    $form.Controls.Add($filePathTextBox)

    # Browse Button
    $browseButton = New-Object System.Windows.Forms.Button
    $browseButton.Location = New-Object System.Drawing.Point(200,38)
    $browseButton.Size = New-Object System.Drawing.Size(75,23)
    $browseButton.Text = "Browse"
    $browseButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($browseButton)
    $browseButton.Add_Click({browseClicked})

    $form.Topmost = $true

    $form.Add_Shown({$form.Activate()})
    $result = $form.ShowDialog()
}

function browseClicked() {
	$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "CSV Files (*.csv)|*.csv"
	$openFileDialog.ShowHelp = $true
    $result = $openFileDialog.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $sourceCSV = Import-Csv $openFileDialog.FileName
        $columnHeaders = ((Get-Content $openFileDialog.FileName)[0] -split(','))
        selectBox
    }
}

function selectBox() {
    $selectBox = New-Object System.Windows.Forms.Form
    $selectBox.Text = "Select a Column"
    $selectBox.Size = New-Object System.Drawing.Size(300,200)
    $selectBox.StartPosition = "CenterScreen"

    $selectBox.KeyPreview = $True
    $selectBox.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
        {loadColumns($objListBox.SelectedItems);$selectBox.Close()}})
    $selectBox.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
        {$selectBox.Close()}})

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Size(75,120)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.Add_Click({loadColumns($objListBox.SelectedItems);$selectBox.Close()})
    $selectBox.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Size(150,120)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.Add_Click({$selectBox.Close()})
    $selectBox.Controls.Add($CancelButton)

    $objLabel = New-Object System.Windows.Forms.Label

    $objLabel.Location = New-Object System.Drawing.Size(10,20) 
    $objLabel.Size = New-Object System.Drawing.Size(280,20) 
    $objLabel.Text = "Please select a column:"
    $selectBox.Controls.Add($objLabel) 

    $objListBox = New-Object System.Windows.Forms.ListBox 
    $objListBox.Location = New-Object System.Drawing.Size(10,40) 
    $objListBox.Size = New-Object System.Drawing.Size(260,20) 
    $objListBox.Height = 80
    $objListBox.SelectionMode = "MultiExtended"

    $columnHeaders | ForEach-Object {[void] $objListBox.Items.Add($_)}

    $selectBox.Controls.Add($objListBox)

    $selectBox.Topmost = $True

    $selectBox.Add_Shown({$selectBox.Activate()})
    [void] $selectBox.ShowDialog()
}

function loadColumns($selectedColumns) {
    $columns = @()
    $columns = $sourceCSV | Select -Property $selectedColumns

    $saveChooser = New-Object -TypeName System.Windows.Forms.SaveFileDialog
    $saveChooser.ShowDialog()

    findFuzzydifferencees($columns)
}

function findFuzzydifferencees($columns) {
    $i = 0
    $threshold = 0.75

    foreach ($row in $columns) {
        $output = New-Object -TypeName System.Collections.ArrayList
        $j = 0
        foreach($row in $columns) {
            $searchString = $columns[$i] | ft -HideTableHeaders | Out-String
            $comparedString = $row | ft -HideTableHeaders | Out-String
            $lowerBound = $searchString.Length * $threshold
            $upperBound = $searchString.Length / $threshold

            if (($comparedString.Length -lt $lowerBound) -Or ($comparedString.Length -gt $upperBound)) {
                $differencePercentage = 100
            } else {
                $editDistance = ([Levenshtein]::EditDistance($searchString, $comparedString))
                $differencePercentage = $editDistance / $searchString.length
            }

            $j++
            Write-Host $i $j
            if ($differencePercentage -lt (1 - $threshold)) {
                $properties = @{'Row'=$j;'SearchString'=$searchString;'ComparedString'=$comparedString;'EditDistance'=$editDistance}
                $outputRow = New-Object -TypeName PSObject -Prop $properties
                $output.Add($outputRow)
            }
        }
        $i++
        $output = $output| Group-Object -Property SearchString

        foreach ($row in $output) {
            $body += "<h2>$($row.name)</h2>"
            $body += $row.Group | Select Row,ComparedString,EditDistance | ConvertTo-Html -Fragment -As Table
        }
    }

    ConvertTo-HTML -Head $head -Body $body -PostContent "<h6>$(Get-Date)</h6>" | Out-File $saveChooser.FileName
}

initializeForm