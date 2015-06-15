import massive.munit.TestSuite;

import TaskExecutorsTest;
import TaskTest;

/**
 * Auto generated Test Suite for MassiveUnit.
 * Refer to munit command line tool for more information (haxelib run munit)
 */

class TestSuite extends massive.munit.TestSuite
{		

	public function new()
	{
		super();

		add(TaskExecutorsTest);
		add(TaskTest);
	}
}
